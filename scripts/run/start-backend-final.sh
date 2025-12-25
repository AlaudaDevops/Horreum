#!/bin/bash

# 后端启动脚本（不带 Quinoa）

export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "$0")"

echo "正在启动 Horreum 后端（端口 8080）..."
echo "数据库已初始化完成"
echo ""

# 临时注释 Quinoa 依赖再启动
mvn quarkus:dev -pl 'horreum-backend' \
  -Dquarkus.quinoa.enabled=false \
  -Dquarkus.test.continuous-testing=disabled
