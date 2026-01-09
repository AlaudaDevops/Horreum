#!/bin/bash
#
# Horreum Kubernetes 部署脚本
# 使用方法: ./deploy.sh [deploy|delete|status]
#

set -e

NAMESPACE="horreum"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 kubectl 是否可用
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装或不在 PATH 中"
        exit 1
    fi
}

# 部署函数
deploy() {
    log_info "开始部署 Horreum..."

    log_info "[1/7] 创建 Namespace..."
    kubectl apply -f ${SCRIPT_DIR}/namespace.yaml

    log_info "[2/7] 创建 Secrets..."
    log_warn "请确保已修改 secrets/ 目录下的默认密码!"
    kubectl apply -f ${SCRIPT_DIR}/secrets/

    log_info "[3/7] 创建 ConfigMaps..."
    kubectl apply -f ${SCRIPT_DIR}/configmaps/

    log_info "[4/7] 创建 PVC..."
    kubectl apply -f ${SCRIPT_DIR}/storage/

    log_info "[5/7] 部署 PostgreSQL..."
    kubectl apply -f ${SCRIPT_DIR}/deployments/postgres-deployment.yaml
    kubectl apply -f ${SCRIPT_DIR}/services/postgres-service.yaml
    log_info "等待 PostgreSQL 就绪..."
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=120s || {
        log_error "PostgreSQL 启动超时"
        exit 1
    }

    log_info "[6/7] 部署 Artemis MQ..."
    kubectl apply -f ${SCRIPT_DIR}/deployments/artemis-deployment.yaml
    kubectl apply -f ${SCRIPT_DIR}/services/artemis-service.yaml
    log_info "等待 Artemis 就绪..."
    kubectl wait --for=condition=ready pod -l app=artemis -n ${NAMESPACE} --timeout=120s || {
        log_error "Artemis 启动超时"
        exit 1
    }

    log_info "[7/7] 部署 Horreum..."
    kubectl apply -f ${SCRIPT_DIR}/deployments/horreum-deployment.yaml
    kubectl apply -f ${SCRIPT_DIR}/services/horreum-service.yaml
    log_info "等待 Horreum 就绪 (可能需要 2-3 分钟)..."
    kubectl wait --for=condition=ready pod -l app=horreum -n ${NAMESPACE} --timeout=300s || {
        log_error "Horreum 启动超时，请检查日志: kubectl logs -l app=horreum -n ${NAMESPACE}"
        exit 1
    }

    echo ""
    log_info "=========================================="
    log_info "Horreum 部署完成!"
    log_info "=========================================="

    # 获取访问地址
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "<node-ip>")
    echo ""
    log_info "访问地址: http://${NODE_IP}:30080"
    log_info "默认账号: horreum.bootstrap"
    log_info "默认密码: <你在 horreum-secret.yaml 中设置的密码>"
    echo ""
}

# 删除函数
delete() {
    log_warn "即将删除 Horreum 命名空间及所有资源..."
    read -p "确认删除? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        kubectl delete namespace ${NAMESPACE} --ignore-not-found
        log_info "Horreum 已删除"
    else
        log_info "取消删除"
    fi
}

# 状态检查函数
status() {
    log_info "Horreum 部署状态:"
    echo ""

    echo "=== Pods ==="
    kubectl get pods -n ${NAMESPACE} -o wide 2>/dev/null || log_warn "Namespace ${NAMESPACE} 不存在"
    echo ""

    echo "=== Services ==="
    kubectl get svc -n ${NAMESPACE} 2>/dev/null || true
    echo ""

    echo "=== PVC ==="
    kubectl get pvc -n ${NAMESPACE} 2>/dev/null || true
    echo ""

    # 健康检查
    if kubectl get pod -l app=horreum -n ${NAMESPACE} -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        log_info "尝试健康检查..."
        kubectl exec -n ${NAMESPACE} $(kubectl get pod -l app=horreum -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:8080/q/health 2>/dev/null | head -20 || log_warn "无法执行健康检查"
    fi
}

# 主函数
main() {
    check_kubectl

    case "${1:-deploy}" in
        deploy)
            deploy
            ;;
        delete)
            delete
            ;;
        status)
            status
            ;;
        *)
            echo "使用方法: $0 [deploy|delete|status]"
            echo ""
            echo "  deploy  - 部署 Horreum (默认)"
            echo "  delete  - 删除 Horreum"
            echo "  status  - 查看部署状态"
            exit 1
            ;;
    esac
}

main "$@"
