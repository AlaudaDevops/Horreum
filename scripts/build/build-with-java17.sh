#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  安装 Java 17 并构建 Horreum${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 检查 Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}错误: 未找到 Homebrew${NC}"
    echo "请访问 https://brew.sh 安装 Homebrew"
    exit 1
fi
echo -e "${GREEN}✓ Homebrew 已安装${NC}\n"

# 检查是否已有 Java 17
if /usr/libexec/java_home -v 17 &> /dev/null; then
    JAVA_17_HOME=$(/usr/libexec/java_home -v 17)
    echo -e "${GREEN}✓ Java 17 已安装${NC}"
    echo "  路径: $JAVA_17_HOME"
else
    echo -e "${YELLOW}Java 17 未安装，正在安装...${NC}"
    echo "这可能需要几分钟..."

    brew install openjdk@17

    # 创建符号链接
    sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk 2>/dev/null || true

    JAVA_17_HOME=$(/usr/libexec/java_home -v 17)
    echo -e "${GREEN}✓ Java 17 安装完成${NC}"
    echo "  路径: $JAVA_17_HOME"
fi

echo ""
echo -e "${YELLOW}步骤 1/3: 使用 Java 17 编译项目${NC}"

# 设置 Java 17 环境
export JAVA_HOME=$JAVA_17_HOME
export PATH="$JAVA_HOME/bin:$PATH"

echo "Java 版本:"
java -version

echo ""
echo "Maven 版本:"
mvn -version

echo ""
echo "开始构建（跳过测试，约 5-10 分钟）..."
mvn clean package -DskipTests -DskipITs -pl horreum-backend -am

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Maven 构建失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Maven 构建完成${NC}\n"

echo -e "${YELLOW}步骤 2/3: 准备镜像构建${NC}"

# 检查构建产物
if [ ! -d "horreum-backend/target/quarkus-app" ]; then
    echo -e "${RED}✗ 构建产物未找到${NC}"
    exit 1
fi

# 创建构建目录
BUILD_DIR="./docker-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 复制构建产物
echo "复制构建产物..."
cp -r horreum-backend/target/quarkus-app "$BUILD_DIR/"

# 创建 Dockerfile（简化版，不需要 Hunter）
cat > "$BUILD_DIR/Dockerfile" << 'EOF'
FROM registry.access.redhat.com/ubi9/openjdk-17-runtime:latest

USER root

# 安装 Python 和基本工具（可选，用于 Hunter）
RUN microdnf install -y python3 python3-pip git && \
    microdnf clean all && \
    pip3 install --no-cache-dir git+https://github.com/datastax-labs/hunter@5c0b480815a281322ebbbf157f70fc785212a892 || true

USER 185

# 复制应用
COPY --chown=185 quarkus-app/lib/ /deployments/lib/
COPY --chown=185 quarkus-app/*.jar /deployments/
COPY --chown=185 quarkus-app/app/ /deployments/app/
COPY --chown=185 quarkus-app/quarkus/ /deployments/quarkus/

WORKDIR /deployments

ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

EXPOSE 8080

CMD ["java", \
     "-Dquarkus.http.host=0.0.0.0", \
     "-Djava.util.logging.manager=org.jboss.logmanager.LogManager", \
     "-jar", "/deployments/quarkus-run.jar"]
EOF

echo -e "${GREEN}✓ Dockerfile 已创建${NC}\n"

echo -e "${YELLOW}步骤 3/3: 构建 Podman 镜像${NC}"

cd "$BUILD_DIR"
podman build --platform linux/arm64 -t localhost/horreum-no-oidc:latest -f Dockerfile .

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 镜像构建失败${NC}"
    exit 1
fi

cd ..

echo -e "${GREEN}✓ 镜像构建完成${NC}\n"

# 清理
echo "清理临时文件..."
rm -rf "$BUILD_DIR"

# 验证
echo -e "${YELLOW}验证镜像...${NC}"
podman images localhost/horreum-no-oidc

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ 构建成功！${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo "镜像: localhost/horreum-no-oidc:latest"
echo ""
echo "下一步:"
echo "  ./run-custom-horreum.sh"
