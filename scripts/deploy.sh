#!/bin/bash

# WordPecker App 部署脚本
# 用于生产环境快速部署

set -e

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.prod.yml"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose 未安装，请先安装 Docker Compose"
        exit 1
    fi
    
    # 检查 Docker 服务是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行，请启动 Docker 服务"
        exit 1
    fi
    
    log_success "系统依赖检查完成"
}

# 创建环境配置文件
create_env_file() {
    log_info "配置环境变量..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_info "创建环境配置文件: $ENV_FILE"
        
        cat > "$ENV_FILE" << 'EOF'
# ==============================================
# WordPecker App 生产环境配置
# ==============================================

# 必需配置 - 请填写实际值
OPENAI_API_KEY=your_openai_api_key_here
GITHUB_REPOSITORY=username/wordpecker-app

# 可选配置 - 用于增强功能
ELEVENLABS_API_KEY=your_elevenlabs_api_key
PEXELS_API_KEY=your_pexels_api_key
OPENAI_BASE_URL=https://api.openai.com/v1

# 镜像配置
IMAGE_TAG=latest

# 端口配置
FRONTEND_PORT=3000
BACKEND_PORT=3001
MONGODB_PORT=27017

# 数据库配置
MONGODB_PASSWORD=wordpecker_secure_password_123

# Nginx 配置 (可选)
NGINX_PORT=80
NGINX_HTTPS_PORT=443
EOF
        
        log_warning "请编辑 .env 文件并填写正确的 API 密钥"
        log_info "主要需要配置: OPENAI_API_KEY 和 GITHUB_REPOSITORY"
        
        # 提示用户编辑配置
        if command -v nano &> /dev/null; then
            read -p "是否现在编辑配置文件? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                nano "$ENV_FILE"
            fi
        fi
    else
        log_info "环境配置文件已存在: $ENV_FILE"
    fi
}

# 验证环境配置
validate_env() {
    log_info "验证环境配置..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "环境配置文件不存在: $ENV_FILE"
        exit 1
    fi
    
    # 加载环境变量
    source "$ENV_FILE"
    
    # 检查必需的环境变量
    if [[ -z "$OPENAI_API_KEY" || "$OPENAI_API_KEY" == "your_openai_api_key_here" ]]; then
        log_error "请在 .env 文件中设置正确的 OPENAI_API_KEY"
        exit 1
    fi
    
    if [[ -z "$GITHUB_REPOSITORY" || "$GITHUB_REPOSITORY" == "username/wordpecker-app" ]]; then
        log_error "请在 .env 文件中设置正确的 GITHUB_REPOSITORY"
        exit 1
    fi
    
    log_success "环境配置验证通过"
}

# 拉取最新镜像
pull_images() {
    log_info "拉取最新容器镜像..."
    
    # 加载环境变量
    source "$ENV_FILE"
    
    local backend_image="ghcr.io/${GITHUB_REPOSITORY}-backend:${IMAGE_TAG}"
    local frontend_image="ghcr.io/${GITHUB_REPOSITORY}-frontend:${IMAGE_TAG}"
    
    log_info "拉取后端镜像: $backend_image"
    if docker pull "$backend_image"; then
        log_success "后端镜像拉取成功"
    else
        log_error "后端镜像拉取失败，请检查仓库名称和权限"
        exit 1
    fi
    
    log_info "拉取前端镜像: $frontend_image"
    if docker pull "$frontend_image"; then
        log_success "前端镜像拉取成功"
    else
        log_error "前端镜像拉取失败，请检查仓库名称和权限"
        exit 1
    fi
    
    # 拉取基础镜像
    log_info "拉取 MongoDB 镜像..."
    docker pull mongo:7.0
    
    log_success "所有镜像拉取完成"
}

# 启动服务
start_services() {
    log_info "启动 WordPecker App 服务..."
    
    cd "$PROJECT_ROOT"
    
    # 停止现有服务（如果存在）
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_info "停止现有服务..."
        docker-compose -f "$COMPOSE_FILE" down
    fi
    
    # 启动新服务
    log_info "启动所有服务..."
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        exit 1
    fi
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."
    
    local max_wait=300  # 最大等待时间 5 分钟
    local wait_time=0
    local check_interval=10
    
    # 加载环境变量
    source "$ENV_FILE"
    
    while [[ $wait_time -lt $max_wait ]]; do
        log_info "检查服务状态... (${wait_time}s/${max_wait}s)"
        
        # 检查后端健康状态
        if curl -sf "http://localhost:${BACKEND_PORT}/api/lists" > /dev/null 2>&1; then
            log_success "后端服务就绪"
            
            # 检查前端服务
            if curl -sf "http://localhost:${FRONTEND_PORT}" > /dev/null 2>&1; then
                log_success "前端服务就绪"
                log_success "所有服务已启动并运行正常"
                return 0
            fi
        fi
        
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    log_error "服务启动超时，请检查日志"
    docker-compose -f "$COMPOSE_FILE" logs
    exit 1
}

# 显示部署信息
show_deployment_info() {
    # 加载环境变量
    source "$ENV_FILE"
    
    log_success "🎉 WordPecker App 部署完成!"
    echo
    echo "📋 部署信息:"
    echo "  • 前端应用: http://localhost:${FRONTEND_PORT}"
    echo "  • 后端 API: http://localhost:${BACKEND_PORT}"
    echo "  • 数据库端口: ${MONGODB_PORT}"
    echo
    echo "🔧 管理命令:"
    echo "  • 查看日志: docker-compose -f $COMPOSE_FILE logs -f"
    echo "  • 停止服务: docker-compose -f $COMPOSE_FILE down"
    echo "  • 重启服务: docker-compose -f $COMPOSE_FILE restart"
    echo "  • 查看状态: docker-compose -f $COMPOSE_FILE ps"
    echo
    echo "📚 更多信息请查看: DEPLOYMENT.md"
}

# 清理函数
cleanup() {
    log_info "停止所有服务..."
    cd "$PROJECT_ROOT"
    docker-compose -f "$COMPOSE_FILE" down
    log_success "清理完成"
}

# 显示帮助信息
show_help() {
    echo "WordPecker App 部署脚本"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  deploy     完整部署流程 (默认)"
    echo "  start      启动服务"
    echo "  stop       停止服务"
    echo "  restart    重启服务"
    echo "  logs       查看日志"
    echo "  status     查看状态"
    echo "  update     更新到最新版本"
    echo "  cleanup    清理和停止所有服务"
    echo "  help       显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 deploy     # 完整部署"
    echo "  $0 start      # 启动服务"
    echo "  $0 logs       # 查看实时日志"
}

# 主函数
main() {
    local action="${1:-deploy}"
    
    case "$action" in
        "deploy")
            log_info "开始 WordPecker App 完整部署流程..."
            check_dependencies
            create_env_file
            validate_env
            pull_images
            start_services
            wait_for_services
            show_deployment_info
            ;;
        "start")
            log_info "启动 WordPecker App..."
            validate_env
            start_services
            wait_for_services
            show_deployment_info
            ;;
        "stop")
            log_info "停止 WordPecker App..."
            cd "$PROJECT_ROOT"
            docker-compose -f "$COMPOSE_FILE" down
            log_success "服务已停止"
            ;;
        "restart")
            log_info "重启 WordPecker App..."
            cd "$PROJECT_ROOT"
            docker-compose -f "$COMPOSE_FILE" restart
            wait_for_services
            show_deployment_info
            ;;
        "logs")
            cd "$PROJECT_ROOT"
            docker-compose -f "$COMPOSE_FILE" logs -f
            ;;
        "status")
            cd "$PROJECT_ROOT"
            docker-compose -f "$COMPOSE_FILE" ps
            ;;
        "update")
            log_info "更新 WordPecker App 到最新版本..."
            validate_env
            pull_images
            cd "$PROJECT_ROOT"
            docker-compose -f "$COMPOSE_FILE" up -d
            wait_for_services
            show_deployment_info
            ;;
        "cleanup")
            cleanup
            ;;
        "help")
            show_help
            ;;
        *)
            log_error "未知操作: $action"
            show_help
            exit 1
            ;;
    esac
}

# 信号处理
trap cleanup EXIT

# 运行主函数
main "$@"