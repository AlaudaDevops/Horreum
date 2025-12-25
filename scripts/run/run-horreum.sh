#!/bin/bash

# Horreum 运行脚本（禁用 Keycloak，使用数据库认证）

# 设置 Java 17
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "$0")/horreum-backend"

echo "启动 Horreum (使用数据库认证，禁用 Keycloak)..."
echo "================================================"
echo "Java 版本: $($JAVA_HOME/bin/java -version 2>&1 | head -n 1)"
echo "数据库: 192.168.0.141:5432/horreum"
echo "AMQP: 192.168.0.141:5672"
echo "认证方式: 数据库认证"
echo "访问地址: http://localhost:8080"
echo "================================================"
echo ""

java -jar target/quarkus-app/quarkus-run.jar
