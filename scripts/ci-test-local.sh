#!/bin/bash
#
# CI 本地预检脚本 - 清理缓存后本地构建（比容器方式更快）
# 用法: ./scripts/ci-test-local.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Horreum CI 本地预检脚本 ===${NC}"

cd "$PROJECT_ROOT"

# 清理本地缓存
echo -e "${YELLOW}清理本地 Maven 缓存...${NC}"
rm -rf ~/.m2/repository/io/hyperfoil/tools/
echo "已清理 ~/.m2/repository/io/hyperfoil/tools/"

echo -e "${YELLOW}=== 步骤 1/2: 安装依赖模块 ===${NC}"
# 使用 jar:jar install:install 跳过 Quarkus 扩展插件验证
mvn jar:jar install:install -DskipTests \
    -pl horreum-api,infra/horreum-dev-services/runtime \
    -am -q

echo -e "${YELLOW}=== 步骤 2/2: 构建 Backend ===${NC}"
mvn package -DskipTests -DskipITs \
    -pl horreum-backend \
    -Dquarkus.package.jar.type=fast-jar \
    -Dquarkus.quinoa=true \
    -Dquarkus.container-image.build=false

echo -e "${YELLOW}=== 构建产物 ===${NC}"
ls -la horreum-backend/target/quarkus-app/

echo -e "${GREEN}=== CI 本地预检成功 ===${NC}"
echo "可以安全推送到远程仓库"
