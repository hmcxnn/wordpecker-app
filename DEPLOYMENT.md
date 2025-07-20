# 🚀 WordPecker App - 自动部署指南

## 概述

本项目已配置完整的 CI/CD 流水线，支持自动构建和部署到 GitHub Container Registry。

## 部署架构

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │    MongoDB      │
│   (React App)   │───▶│  (Express API)  │───▶│   (Database)    │
│   Port: 3000    │    │   Port: 3001    │    │   Port: 27017   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔄 CI/CD 流程

### 触发条件
- **推送到 main/develop 分支**: 自动构建和部署
- **创建 Tag (v*)**: 发布版本
- **Pull Request**: 构建验证
- **手动触发**: 可选择部署环境

### 构建阶段
1. **代码质量检查**: ESLint, TypeScript 编译, 测试
2. **多架构构建**: linux/amd64, linux/arm64
3. **安全扫描**: SBOM 生成和漏洞扫描
4. **镜像推送**: GitHub Container Registry

### 部署产物
- `ghcr.io/username/wordpecker-app-backend:latest`
- `ghcr.io/username/wordpecker-app-frontend:latest`
- `ghcr.io/username/wordpecker-app-full:latest`

## 📦 容器镜像

### Backend 镜像
```bash
docker pull ghcr.io/USERNAME/REPO-backend:latest
```

### Frontend 镜像
```bash
docker pull ghcr.io/USERNAME/REPO-frontend:latest
```

## 🚀 部署方式

### 方式 1: 使用 Docker Compose (推荐)

1. **下载部署配置**:
```bash
curl -O https://raw.githubusercontent.com/USERNAME/REPO/main/docker-compose.prod.yml
```

2. **设置环境变量**:
```bash
# 创建 .env 文件
cat > .env << EOF
# 必需配置
OPENAI_API_KEY=your_openai_api_key_here
GITHUB_REPOSITORY=username/repo-name

# 可选配置
ELEVENLABS_API_KEY=your_elevenlabs_api_key
PEXELS_API_KEY=your_pexels_api_key
IMAGE_TAG=latest

# 端口配置
FRONTEND_PORT=3000
BACKEND_PORT=3001
MONGODB_PORT=27017
MONGODB_PASSWORD=your_secure_password
EOF
```

3. **启动应用**:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### 方式 2: 使用独立容器

```bash
# 创建网络
docker network create wordpecker-net

# 启动 MongoDB
docker run -d --name wordpecker-mongo \
  --network wordpecker-net \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=password \
  -e MONGO_INITDB_DATABASE=wordpecker \
  -p 27017:27017 \
  mongo:7.0

# 启动后端
docker run -d --name wordpecker-backend \
  --network wordpecker-net \
  -e NODE_ENV=production \
  -e MONGODB_URL=mongodb://admin:password@wordpecker-mongo:27017/wordpecker?authSource=admin \
  -e OPENAI_API_KEY=your_openai_api_key \
  -p 3001:3000 \
  ghcr.io/username/repo-backend:latest

# 启动前端
docker run -d --name wordpecker-frontend \
  --network wordpecker-net \
  -e VITE_API_URL=http://localhost:3001 \
  -p 3000:3000 \
  ghcr.io/username/repo-frontend:latest
```

### 方式 3: 使用 Kubernetes

```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpecker-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wordpecker-backend
  template:
    metadata:
      labels:
        app: wordpecker-backend
    spec:
      containers:
      - name: backend
        image: ghcr.io/username/repo-backend:latest
        ports:
        - containerPort: 3000
        env:
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: wordpecker-secrets
              key: openai-api-key
---
apiVersion: v1
kind: Service
metadata:
  name: wordpecker-backend-service
spec:
  selector:
    app: wordpecker-backend
  ports:
  - port: 3001
    targetPort: 3000
  type: LoadBalancer
```

## 🔧 配置管理

### 环境变量

#### 必需变量
- `OPENAI_API_KEY`: OpenAI API 密钥
- `MONGODB_URL`: MongoDB 连接字符串

#### 可选变量
- `ELEVENLABS_API_KEY`: ElevenLabs 语音 API
- `PEXELS_API_KEY`: Pexels 图片 API
- `OPENAI_BASE_URL`: 自定义 OpenAI 端点
- `NODE_ENV`: 运行环境 (production/development)

### 端口配置
- **前端**: 3000
- **后端**: 3001
- **MongoDB**: 27017

## 🔒 安全配置

### 1. API 密钥管理
```bash
# 在 GitHub 仓库设置中添加 Secrets:
# OPENAI_API_KEY
# ELEVENLABS_API_KEY
# PEXELS_API_KEY
```

### 2. 数据库安全
```bash
# 生产环境使用强密码
MONGODB_PASSWORD=$(openssl rand -base64 32)
```

### 3. 网络安全
```bash
# 限制数据库访问
docker run --name wordpecker-mongo \
  --network wordpecker-net \
  --no-healthcheck \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=$MONGODB_PASSWORD \
  mongo:7.0
```

## 🔍 监控和日志

### 查看日志
```bash
# 查看所有服务日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.prod.yml logs -f backend
docker-compose -f docker-compose.prod.yml logs -f frontend
```

### 健康检查
```bash
# 检查服务状态
docker-compose -f docker-compose.prod.yml ps

# 健康检查端点
curl http://localhost:3001/api/lists  # Backend
curl http://localhost:3000            # Frontend
```

## 🔄 更新和回滚

### 更新到最新版本
```bash
# 拉取最新镜像
docker-compose -f docker-compose.prod.yml pull

# 重启服务
docker-compose -f docker-compose.prod.yml up -d
```

### 回滚到特定版本
```bash
# 设置镜像标签
export IMAGE_TAG=v1.0.0

# 重新部署
docker-compose -f docker-compose.prod.yml up -d
```

## 🚨 故障排除

### 常见问题

1. **后端无法连接数据库**:
```bash
# 检查 MongoDB 容器状态
docker inspect wordpecker-mongodb-prod

# 检查网络连接
docker exec wordpecker-backend-prod ping mongodb
```

2. **前端无法访问后端**:
```bash
# 检查环境变量
docker exec wordpecker-frontend-prod env | grep VITE_API_URL

# 检查后端健康状态
curl http://localhost:3001/api/lists
```

3. **容器无法启动**:
```bash
# 查看详细错误日志
docker logs wordpecker-backend-prod
docker logs wordpecker-frontend-prod
```

### 性能优化

1. **资源限制**:
```yaml
# 在 docker-compose.prod.yml 中添加
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.5'
      memory: 512M
```

2. **缓存优化**:
```bash
# 启用 Docker buildx 缓存
export DOCKER_BUILDKIT=1
```

## 📊 监控仪表板

访问应用监控信息:
- **应用状态**: http://localhost:3000
- **API 文档**: http://localhost:3001/api
- **数据库**: localhost:27017 (需要认证)

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支: `git checkout -b feature/amazing-feature`
3. 提交更改: `git commit -m 'Add amazing feature'`
4. 推送分支: `git push origin feature/amazing-feature`
5. 创建 Pull Request

自动化流水线将验证您的更改并提供反馈。