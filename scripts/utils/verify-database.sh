#!/bin/bash

# 数据库表结构验证脚本

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  数据库表结构验证${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 检查 PostgreSQL 连接
echo "检查数据库连接..."
if ! PGPASSWORD=horreum psql -h localhost -p 5432 -U horreum -d horreum -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${RED}✗ 无法连接到数据库${NC}"
    echo "请确保 PostgreSQL 容器正在运行"
    exit 1
fi
echo -e "${GREEN}✓ 数据库连接成功${NC}\n"

# 检查关键表
echo "检查关键表..."
TABLES=("run" "run_schemas" "schema" "test" "dataset" "databasechangelog")

for table in "${TABLES[@]}"; do
    if PGPASSWORD=horreum psql -h localhost -p 5432 -U horreum -d horreum -c "\d $table" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $table"
    else
        echo -e "  ${RED}✗${NC} $table (不存在)"
    fi
done

# 统计 Liquibase 变更集
echo ""
echo "Liquibase 迁移统计:"
CHANGESETS=$(PGPASSWORD=horreum psql -h localhost -p 5432 -U horreum -d horreum -t -c "SELECT COUNT(*) FROM databasechangelog;" 2>/dev/null | xargs)
if [ -n "$CHANGESETS" ]; then
    echo -e "  已执行 ${GREEN}$CHANGESETS${NC} 个 changesets"
else
    echo -e "  ${YELLOW}⚠ databasechangelog 表不存在（Liquibase 未运行）${NC}"
fi

# 检查 run_schemas 表结构
echo ""
echo "run_schemas 表结构:"
if PGPASSWORD=horreum psql -h localhost -p 5432 -U horreum -d horreum -c "\d run_schemas" > /dev/null 2>&1; then
    PGPASSWORD=horreum psql -h localhost -p 5432 -U horreum -d horreum -c "\d run_schemas" | grep -E "Column|Type" | head -10
else
    echo -e "  ${RED}表不存在${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
