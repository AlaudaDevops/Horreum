#!/bin/bash

# Horreum 示例数据导入工具（支持数据库认证和 API Key）

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

EX="$(dirname "$0")/infra-legacy/example-data"
API="http://localhost:8080/api"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Horreum 示例数据导入工具${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 检查 Horreum 服务
echo "检查 Horreum 服务..."
if ! curl -s -o /dev/null -w "%{http_code}" $API/config/keycloak | grep -q "200"; then
    echo -e "${RED}错误: 无法连接到 Horreum ($API)${NC}"
    echo "请确保 Horreum 正在运行在 http://localhost:8080"
    exit 1
fi
echo -e "${GREEN}✓ Horreum 服务运行中${NC}\n"

# 获取 Keycloak 配置
KEYCLOAK_URL=$(curl -s $API/config/keycloak | jq -r '.url // empty')

# 认证方式选择
if [ -n "$KEYCLOAK_URL" ]; then
    echo -e "检测到 ${GREEN}Keycloak 认证${NC}"
    echo "  Keycloak URL: $KEYCLOAK_URL"

    TOKEN=$(curl -s -X POST $KEYCLOAK_URL/realms/horreum/protocol/openid-connect/token \
        -H 'content-type: application/x-www-form-urlencoded' \
        -d 'username=horreum.bootstrap&password=secret&grant_type=password&client_id=horreum-ui' \
        | jq -r '.access_token // empty')

    if [ -z "$TOKEN" ]; then
        echo -e "${RED}✗ 无法获取 Token${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 认证成功${NC}\n"
    AUTH_HEADER="Authorization: Bearer $TOKEN"
else
    echo -e "检测到 ${YELLOW}数据库认证模式${NC}\n"
    echo "请选择认证方式："
    echo "  1) 使用现有的 API Key"
    echo "  2) 创建新的 API Key（需要登录浏览器）"
    echo "  3) 取消"
    read -p "请选择 [1-3]: " auth_choice

    case $auth_choice in
        1)
            read -p "请输入 API Key: " API_KEY
            if [ -z "$API_KEY" ]; then
                echo -e "${RED}API Key 不能为空${NC}"
                exit 1
            fi
            AUTH_HEADER="X-Horreum-API-Key: $API_KEY"
            ;;
        2)
            echo ""
            echo -e "${YELLOW}创建 API Key 步骤:${NC}"
            echo "  1. 打开浏览器访问: ${BLUE}http://localhost:8080${NC}"
            echo "  2. 使用 ${GREEN}horreum.bootstrap${NC} / ${GREEN}secret${NC} 登录"
            echo "  3. 点击右上角用户名 -> Profile"
            echo "  4. 在 'API Keys' 标签页点击 'New Key'"
            echo "  5. 输入名称 (例如: import-script)，选择类型 'Personal'"
            echo "  6. 复制生成的 API Key"
            echo ""
            read -p "完成后，请粘贴 API Key: " API_KEY

            if [ -z "$API_KEY" ]; then
                echo -e "${RED}API Key 不能为空${NC}"
                exit 1
            fi
            AUTH_HEADER="X-Horreum-API-Key: $API_KEY"
            ;;
        3)
            echo "已取消"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac

    # 测试 API Key
    echo ""
    echo "测试 API Key..."
    TEST_RESULT=$(curl -s -w "\n%{http_code}" -H "$AUTH_HEADER" $API/user/roles)
    HTTP_CODE=$(echo "$TEST_RESULT" | tail -n1)

    if [ "$HTTP_CODE" != "200" ]; then
        echo -e "${RED}✗ API Key 无效或已过期 (HTTP $HTTP_CODE)${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ API Key 验证成功${NC}\n"
fi

# 辅助函数
fail() {
    echo -e "\n${RED}##########################${NC}" 1>&2
    echo -e "${RED}#      导入失败          #${NC}" 1>&2
    echo -e "${RED}##########################${NC}" 1>&2
    exit 1
}

post() {
    local SILENT=false
    if [ "$1" = "-s" ]; then
        SILENT=true
        shift
    fi

    local ENDPOINT=$1
    local BODY_FILE=$2
    local CONTENT_TYPE=${3:-"application/json"}

    if [[ "$BODY_FILE" == *.json ]]; then
        if [[ "$BODY_FILE" == /* ]]; then
            BODY="@$BODY_FILE"
        else
            BODY="@${EX}/$BODY_FILE"
        fi
    else
        BODY="$BODY_FILE"
    fi

    if [ "$SILENT" = false ]; then
        echo -ne "  POST $ENDPOINT ... "
    fi

    RESULT=$(curl -s -w "\n%{http_code}" -H "$AUTH_HEADER" -H "Content-Type: $CONTENT_TYPE" -d "$BODY" ${API}${ENDPOINT})
    HTTP_CODE=$(echo "$RESULT" | tail -n1)
    BODY_RESULT=$(echo "$RESULT" | head -n-1)

    if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "204" ]; then
        if [ "$SILENT" = false ]; then
            echo -e "${RED}✗ (HTTP $HTTP_CODE)${NC}"
        fi
        echo -e "${RED}响应: $BODY_RESULT${NC}" >&2
        fail
    fi

    if [ "$SILENT" = false ]; then
        echo -e "${GREEN}✓${NC}"
    fi

    echo "$BODY_RESULT"
}

requireId() {
    if [ -z "${!1}" ]; then
        echo -e "${RED}错误: $1 为空 - 上一个请求可能失败${NC}" >&2
        fail
    elif [[ ! ( "${!1}" =~ ^[0-9]+$ ) ]]; then
        echo -e "${RED}错误: 这不是一个有效的 ID: ${!1}${NC}" >&2
        fail
    fi
}

combine() {
    local FILE=$(mktemp)
    if [[ "$1" == /* ]]; then
        BASE=$1
    else
        BASE=$EX/$1
    fi
    shift
    cat $BASE | jq -r $@ > $FILE
    mv $FILE $FILE.json
    echo $FILE.json
}

# 开始导入
echo -e "${BLUE}开始导入示例数据...${NC}\n"

echo "1. Schemas"
post -s /schema hyperfoil_schema.json > /dev/null
ACME_BENCHMARK_SCHEMA_ID=$(post /schema acme_benchmark_schema.json)
requireId ACME_BENCHMARK_SCHEMA_ID
ACME_HORREUM_SCHEMA_ID=$(post /schema acme_horreum_schema.json)
requireId ACME_HORREUM_SCHEMA_ID

echo -e "\n2. Transformers"
ACME_TRANSFORMER_ID=$(post /schema/$ACME_BENCHMARK_SCHEMA_ID/transformers acme_transformer.json)
requireId ACME_TRANSFORMER_ID

echo -e "\n3. Tests"
post -s /test protected_test.json > /dev/null
ROADRUNNER_TEST_ID=$(post /test roadrunner_test.json | jq -r '.id')
requireId ROADRUNNER_TEST_ID
post -s /test/$ROADRUNNER_TEST_ID/transformers '['$ACME_TRANSFORMER_ID']' > /dev/null

echo -e "\n4. Runs"
post -s /run/test?test=$ROADRUNNER_TEST_ID roadrunner_run.json > /dev/null

echo -e "\n5. Labels"
post -s /schema/$ACME_HORREUM_SCHEMA_ID/labels test_label.json > /dev/null
post -s /schema/$ACME_HORREUM_SCHEMA_ID/labels throughput_label.json > /dev/null

echo -e "\n6. Alerting & Subscriptions"
post -s /alerting/variables?test=$ROADRUNNER_TEST_ID roadrunner_variables.json > /dev/null
post -s /subscriptions/$ROADRUNNER_TEST_ID roadrunner_watch.json > /dev/null

echo -e "\n7. Notifications"
post -s '/notifications/settings?name=horreum.bootstrap&team=false' '[{ "method": "email", "data": "dummy@example.com" }]' > /dev/null

echo -e "\n8. Actions"
post -s /action/allowedSites 'http://example.com' 'text/plain' > /dev/null
post -s /action new_test_action.json > /dev/null
NEW_RUN=$(combine new_run_action.json '.testId='$ROADRUNNER_TEST_ID)
post -s /action $NEW_RUN > /dev/null
rm -f $NEW_RUN

echo -e "\n9. Backends"
post -s /config/backends elastic-backend.json > /dev/null

echo ""
echo -e "${GREEN}##########################${NC}"
echo -e "${GREEN}#   导入成功完成!        #${NC}"
echo -e "${GREEN}##########################${NC}"
echo ""
echo -e "导入的数据概览:"
echo -e "  ${BLUE}✓${NC} Schemas: 3 个"
echo -e "  ${BLUE}✓${NC} Tests: 2 个"
echo -e "     - Roadrunner Test ID: ${GREEN}$ROADRUNNER_TEST_ID${NC}"
echo -e "  ${BLUE}✓${NC} Runs: 1 个"
echo -e "  ${BLUE}✓${NC} Labels: 2 个"
echo -e "  ${BLUE}✓${NC} Transformers: 1 个"
echo -e "  ${BLUE}✓${NC} Actions: 2 个"
echo -e "  ${BLUE}✓${NC} Subscriptions: 1 个"
echo ""
echo -e "访问 ${BLUE}http://localhost:8080${NC} 查看导入的数据"
echo ""
