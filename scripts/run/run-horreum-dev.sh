#!/bin/bash

# Horreum 开发模式运行脚本（使用外部数据库和Artemis）

# 设置 Java 17
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "$0")"

echo "启动 Horreum 开发模式..."
echo "================================================"
echo "Java 版本: $($JAVA_HOME/bin/java -version 2>&1 | head -n 1)"
echo "数据库: localhost:5432/horreum"
echo "AMQP: localhost:5672 (外部Artemis容器)"
echo "认证方式: 数据库认证"
echo "访问地址: http://localhost:8080"
echo "================================================"
echo ""

mvn quarkus:dev -pl 'horreum-backend'
