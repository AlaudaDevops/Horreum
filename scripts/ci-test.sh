#!/bin/bash
#
# CI 预检脚本 - 使用 Podman 模拟 CI 环境构建
# 用法: ./scripts/ci-test.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Horreum CI 预检脚本 ===${NC}"
echo "项目目录: $PROJECT_ROOT"

# 检查 Podman
if ! command -v podman &> /dev/null; then
    echo -e "${RED}错误: 未找到 podman${NC}"
    exit 1
fi

# 使用与 CI 相同的镜像
CI_IMAGE="docker-mirrors.alauda.cn/library/maven:3.9-eclipse-temurin-17"

echo -e "${YELLOW}拉取 CI 镜像...${NC}"
podman pull "$CI_IMAGE" || true

echo -e "${YELLOW}开始 CI 模拟构建...${NC}"

podman run --rm \
    -v "$PROJECT_ROOT":/workspace:Z \
    -w /workspace \
    --user root \
    "$CI_IMAGE" \
    bash -c '
set -ex

export HOME=/root

echo "=== 步骤 1/2: 安装依赖模块 ==="
# 使用 jar:jar install:install 跳过 Quarkus 扩展插件验证
mvn jar:jar install:install -DskipTests \
    -pl horreum-api,infra/horreum-dev-services/runtime \
    -am

echo "=== 步骤 2/2: 构建 Backend ==="
mvn package -DskipTests -DskipITs \
    -pl horreum-backend \
    -Dquarkus.package.jar.type=fast-jar \
    -Dquarkus.quinoa=true \
    -Dquarkus.container-image.build=false

echo "=== 构建产物 ==="
ls -la horreum-backend/target/quarkus-app/
'

if [ $? -eq 0 ]; then
    echo -e "${GREEN}=== CI 模拟构建成功 ===${NC}"
    echo "可以安全推送到远程仓库"
else
    echo -e "${RED}=== CI 模拟构建失败 ===${NC}"
    echo "请修复问题后再推送"
    exit 1
fi
