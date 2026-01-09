# Horreum Production Dockerfile
# Build context: repository root (after Maven build)

FROM quay.io/hyperfoil/horreum-base:latest

# 复制 Quarkus 构建产物
COPY --chown=185 horreum-backend/target/quarkus-app/lib/ /deployments/lib/
COPY --chown=185 horreum-backend/target/quarkus-app/*.jar /deployments/
COPY --chown=185 horreum-backend/target/quarkus-app/app/ /deployments/app/
COPY --chown=185 horreum-backend/target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080

USER 185

ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"

# 使用项目自带的启动脚本
ENTRYPOINT ["/deployments/horreum.sh"]
