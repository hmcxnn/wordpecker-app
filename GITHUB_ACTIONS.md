# 🚀 WordPecker App - GitHub Actions 自动部署

## 快速开始

### 1. 仓库设置

在 GitHub 仓库的 Settings > Secrets and variables > Actions 中添加必要的密钥：

```bash
# 必需的 Secrets
OPENAI_API_KEY          # OpenAI API 密钥
ELEVENLABS_API_KEY      # ElevenLabs API 密钥 (可选)
PEXELS_API_KEY          # Pexels API 密钥 (可选)
```

### 2. 触发部署

```bash
# 推送到主分支自动触发
git push origin main

# 创建发布标签
git tag v1.0.0
git push origin v1.0.0

# 手动触发部署
# 在 GitHub 仓库的 Actions 页面选择 "Build and Deploy" workflow，点击 "Run workflow"
```

### 3. 部署完成后

访问生成的部署文档：
- **部署指南**: `https://username.github.io/wordpecker-app`
- **容器镜像**: `https://github.com/username/wordpecker-app/pkgs/container`

## 🐳 使用容器镜像

### 快速启动

```bash
# 下载部署脚本
curl -o deploy.sh https://raw.githubusercontent.com/username/wordpecker-app/main/scripts/deploy.sh
chmod +x deploy.sh

# 运行部署
./deploy.sh deploy
```

### 手动部署

```bash
# 下载配置文件
curl -O https://raw.githubusercontent.com/username/wordpecker-app/main/docker-compose.prod.yml

# 设置环境变量
cat > .env << 'EOF'
OPENAI_API_KEY=your_actual_openai_api_key
GITHUB_REPOSITORY=username/wordpecker-app
ELEVENLABS_API_KEY=your_elevenlabs_api_key
PEXELS_API_KEY=your_pexels_api_key
IMAGE_TAG=latest
FRONTEND_PORT=3000
BACKEND_PORT=3001
MONGODB_PORT=27017
MONGODB_PASSWORD=secure_password
EOF

# 启动应用
docker-compose -f docker-compose.prod.yml up -d
```

## 📊 部署状态

部署完成后，可以通过以下方式检查状态：

```bash
# 检查服务状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f

# 健康检查
curl http://localhost:3001/api/lists  # Backend API
curl http://localhost:3000            # Frontend
```

## 🔧 自定义配置

### 环境变量配置

| 变量名 | 描述 | 默认值 | 必需 |
|--------|------|--------|------|
| `OPENAI_API_KEY` | OpenAI API 密钥 | - | ✅ |
| `GITHUB_REPOSITORY` | GitHub 仓库名称 | - | ✅ |
| `ELEVENLABS_API_KEY` | ElevenLabs API 密钥 | - | ❌ |
| `PEXELS_API_KEY` | Pexels API 密钥 | - | ❌ |
| `IMAGE_TAG` | 容器镜像标签 | `latest` | ❌ |
| `FRONTEND_PORT` | 前端端口 | `3000` | ❌ |
| `BACKEND_PORT` | 后端端口 | `3001` | ❌ |
| `MONGODB_PORT` | MongoDB 端口 | `27017` | ❌ |

### 端口配置

默认端口配置：
- **前端**: http://localhost:3000
- **后端**: http://localhost:3001  
- **MongoDB**: localhost:27017

可以通过环境变量自定义端口：

```bash
export FRONTEND_PORT=8080
export BACKEND_PORT=8081
export MONGODB_PORT=27018
```

## 🔄 更新和维护

### 更新到最新版本

```bash
# 使用部署脚本更新
./deploy.sh update

# 或手动更新
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

### 回滚到特定版本

```bash
# 设置特定版本标签
export IMAGE_TAG=v1.0.0

# 重新部署
docker-compose -f docker-compose.prod.yml up -d
```

## 🚨 故障排除

### 常见问题

1. **镜像拉取失败**
```bash
# 检查 GitHub Container Registry 权限
docker login ghcr.io -u username

# 确保仓库名称正确
echo $GITHUB_REPOSITORY
```

2. **服务无法启动**
```bash
# 查看详细错误日志
docker logs wordpecker-backend-prod
docker logs wordpecker-frontend-prod

# 检查端口冲突
netstat -tlnp | grep :3000
netstat -tlnp | grep :3001
```

3. **API 密钥配置错误**
```bash
# 检查环境变量
docker exec wordpecker-backend-prod env | grep OPENAI_API_KEY

# 重新设置环境变量
docker-compose -f docker-compose.prod.yml down
# 编辑 .env 文件
docker-compose -f docker-compose.prod.yml up -d
```

### 性能优化

1. **资源限制**
在 `docker-compose.prod.yml` 中添加资源限制：

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '1.0'
      memory: 1G
```

2. **缓存优化**
启用 Docker 构建缓存：

```bash
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

## 📈 监控和日志

### 日志管理

```bash
# 查看实时日志
docker-compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker-compose -f docker-compose.prod.yml logs -f backend

# 限制日志输出行数
docker-compose -f docker-compose.prod.yml logs --tail=100 backend
```

### 健康监控

```bash
# 创建监控脚本
cat > monitor.sh << 'EOF'
#!/bin/bash
while true; do
  echo "$(date): Checking services..."
  
  # 检查前端
  if curl -sf http://localhost:3000 > /dev/null; then
    echo "✅ Frontend OK"
  else
    echo "❌ Frontend DOWN"
  fi
  
  # 检查后端
  if curl -sf http://localhost:3001/api/lists > /dev/null; then
    echo "✅ Backend OK"
  else
    echo "❌ Backend DOWN"
  fi
  
  sleep 30
done
EOF

chmod +x monitor.sh
./monitor.sh
```

## 🔐 安全最佳实践

1. **API 密钥管理**
   - 使用 GitHub Secrets 存储敏感信息
   - 定期轮换 API 密钥
   - 限制 API 密钥权限范围

2. **容器安全**
   - 定期更新基础镜像
   - 扫描容器漏洞
   - 使用非 root 用户运行容器

3. **网络安全**
   - 限制容器间网络访问
   - 使用防火墙规则
   - 启用 HTTPS (生产环境)

## 📚 更多资源

- [Docker 官方文档](https://docs.docker.com/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [WordPecker App 项目文档](./README.md)