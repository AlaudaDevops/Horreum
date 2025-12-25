---
name: horreum-status
description: Check Horreum running status and health. Use when user asks about Horreum status, whether it's running, or wants to check services.
---

# Horreum Status Check

Check the running status of Horreum and its dependencies.

## Quick Status Commands

### Check All Horreum Processes
```bash
ps aux | grep -E "(quarkus|horreum|java)" | grep -v grep
```

### Check Port Usage
```bash
lsof -i :8080  # Backend
lsof -i :3000  # Frontend (if separate)
lsof -i :5432  # PostgreSQL
lsof -i :5672  # Artemis MQ
lsof -i :5005  # Debug port
```

### Health Check
```bash
curl -s http://localhost:8080/q/health | jq .
```

### API Config Check
```bash
curl -s http://localhost:8080/api/config/keycloak | jq .
```

## Expected Running State

| Service | Port | Process |
|---------|------|---------|
| Horreum Backend | 8080 | java (quarkus) |
| Horreum Frontend | 3000 | node (vite) |
| PostgreSQL | 5432 | postgres |
| Artemis MQ | 5672 | java (artemis) |
| Debug | 5005 | jdwp |

## Database Status

```bash
PGPASSWORD=horreum psql -h localhost -p 5432 -U horreum -d horreum -c "SELECT 1"
```

Or use the verify script:
```bash
./scripts/utils/verify-database.sh
```
