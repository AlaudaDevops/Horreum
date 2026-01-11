#!/bin/bash
#
# 本地构建测试脚本
# 用于验证 .tekton/build-image.yaml 中的 Maven 命令在干净环境下能否成功
#
# 使用方法: ./local-build-test.sh
#

set -e

echo "=========================================="
echo "Horreum 本地构建测试"
echo "模拟 CI 干净环境"
echo "=========================================="

cd "$(dirname "$0")/../.."
PROJECT_ROOT=$(pwd)
echo "项目根目录: $PROJECT_ROOT"

# 1. 清理本地 Maven 缓存（模拟 CI 干净环境）
echo ""
echo "[步骤 1/4] 清理本地 Maven 缓存..."
rm -rf ~/.m2/repository/io/hyperfoil/tools/
echo "已清理 ~/.m2/repository/io/hyperfoil/tools/"

# 2. 清理项目构建目录
echo ""
echo "[步骤 2/4] 清理项目构建目录..."
mvn clean -q
echo "mvn clean 完成"

# 3. 执行与流水线相同的构建命令
echo ""
echo "[步骤 3/4] 执行构建命令..."

echo ""
echo "--- 3.1 编译并安装 horreum-api ---"
mvn compile jar:jar install:install -DskipTests \
  -pl horreum-api \
  -am

echo ""
echo "--- 3.2 安装 dev-services 及其父 POM ---"
mvn jar:jar install:install -DskipTests \
  -pl infra/horreum-dev-services/runtime \
  -am

echo ""
echo "--- 3.3 构建 backend ---"
mvn package -DskipTests -DskipITs \
  -pl horreum-backend \
  -Dquarkus.package.jar.type=fast-jar \
  -Dquarkus.quinoa=false \
  -Dquarkus.container-image.build=false

# 4. 验证构建结果
echo ""
echo "[步骤 4/4] 验证构建结果..."

if [ -d "$PROJECT_ROOT/horreum-backend/target/quarkus-app" ]; then
    echo "✅ 构建成功！"
    echo ""
    echo "构建产物:"
    ls -la "$PROJECT_ROOT/horreum-backend/target/quarkus-app/"
    echo ""
    echo "=========================================="
    echo "本地验证通过，可以提交到远程仓库"
    echo "=========================================="
    exit 0
else
    echo "❌ 构建失败：quarkus-app 目录不存在"
    exit 1
fi
