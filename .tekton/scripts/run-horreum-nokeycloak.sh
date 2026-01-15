#!/bin/bash
#
# 使用 Podman 运行 Horreum 服务（无 Keycloak 模式）
# 包含 PostgreSQL 和 Artemis (AMQP) 依赖
# 使用数据库认证和 HTTP Basic Auth
#

set -e

HORREUM_IMAGE="${HORREUM_IMAGE:-build-harbor.alauda.cn/devops/horreum:alauda-deploy}"
POD_NAME="horreum-nokeycloak"

echo "=========================================="
echo "启动 Horreum 服务（无 Keycloak 模式）"
echo "镜像: $HORREUM_IMAGE"
echo "=========================================="

# 清理旧的 pod（如果存在）
echo "[1/5] 清理旧容器..."
podman pod rm -f $POD_NAME 2>/dev/null || true

# 创建 pod，暴露端口
echo "[2/5] 创建 Pod..."
podman pod create --name $POD_NAME \
  -p 8080:8080 \
  -p 5432:5432 \
  -p 5672:5672 \
  -p 61616:61616

# 启动 PostgreSQL
echo "[3/5] 启动 PostgreSQL..."
podman run -d --pod $POD_NAME \
  --name ${POD_NAME}-postgres \
  -e POSTGRES_USER=dbadmin \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=horreum \
  docker.io/library/postgres:16

# 等待 PostgreSQL 启动
echo "    等待 PostgreSQL 启动..."
sleep 5

# 初始化数据库用户
echo "[4/5] 初始化数据库..."
podman exec ${POD_NAME}-postgres psql -U dbadmin -d horreum -c "
CREATE USER appuser WITH PASSWORD 'secret';
GRANT ALL PRIVILEGES ON DATABASE horreum TO appuser;
GRANT ALL PRIVILEGES ON SCHEMA public TO appuser;
" 2>/dev/null || echo "    用户可能已存在"

# 启动 Artemis (AMQP)
echo "[4/5] 启动 Apache Artemis (AMQP)..."
podman run -d --pod $POD_NAME \
  --name ${POD_NAME}-artemis \
  -e AMQ_USER=horreum \
  -e AMQ_PASSWORD=secret \
  -e AMQ_ROLE=admin \
  -e AMQ_ALLOW_ANONYMOUS=false \
  quay.io/artemiscloud/activemq-artemis-broker:1.0.25

echo "    等待 Artemis 启动..."
sleep 10

# 启动 Horreum（无 Keycloak 模式）
echo "[5/5] 启动 Horreum（无 Keycloak 模式）..."
podman run -d --pod $POD_NAME \
  --name ${POD_NAME}-app \
  -e QUARKUS_PROFILE=nokeycloak \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://localhost:5432/horreum \
  -e QUARKUS_DATASOURCE_USERNAME=appuser \
  -e QUARKUS_DATASOURCE_PASSWORD=secret \
  -e QUARKUS_DATASOURCE_JDBC_ADDITIONAL_JDBC_PROPERTIES_SSL=false \
  -e QUARKUS_DATASOURCE_MIGRATION_JDBC_URL=jdbc:postgresql://localhost:5432/horreum \
  -e QUARKUS_DATASOURCE_MIGRATION_USERNAME=dbadmin \
  -e QUARKUS_DATASOURCE_MIGRATION_PASSWORD=secret \
  -e HORREUM_KEYCLOAK_URL= \
  -e QUARKUS_OIDC_ENABLED=false \
  -e QUARKUS_KEYCLOAK_ADMIN_CLIENT_ENABLED=false \
  -e HORREUM_ROLES_PROVIDER=database \
  -e HORREUM_BOOTSTRAP_PASSWORD=secret \
  -e HORREUM_URL=http://localhost:8080 \
  -e HORREUM_INTERNAL_URL=http://localhost:8080 \
  -e AMQP_HOST=localhost \
  -e AMQP_PORT=5672 \
  -e AMQP_USERNAME=horreum \
  -e AMQP_PASSWORD=secret \
  $HORREUM_IMAGE

echo ""
echo "=========================================="
echo "服务启动中..."
echo ""
echo "访问地址:"
echo "  - Horreum: http://localhost:8080"
echo ""
echo "默认凭据（Basic Auth）:"
echo "  - 用户名: horreum.bootstrap"
echo "  - 密码:   secret"
echo ""
echo "测试登录:"
echo "  curl -u 'horreum.bootstrap:secret' http://localhost:8080/api/user/me"
echo ""
echo "查看日志: podman logs -f ${POD_NAME}-app"
echo "停止服务: podman pod stop $POD_NAME"
echo "删除服务: podman pod rm -f $POD_NAME"
echo "=========================================="
