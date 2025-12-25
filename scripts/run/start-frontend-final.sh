#!/bin/bash

# 前端启动脚本

cd "$(dirname "$0")/horreum-web"

echo "正在启动 Horreum 前端（端口 3000）..."
echo "请确保后端已在 8080 端口运行"
echo ""

npm run dev
