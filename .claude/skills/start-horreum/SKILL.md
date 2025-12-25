---
name: start-horreum
description: Start Horreum development environment. Use when user wants to start, run, or launch Horreum backend and frontend services.
---

# Start Horreum

Start the Horreum performance testing platform in development mode.

## Current Configuration

- **Auth Mode**: Database authentication (no Keycloak)
- **Database**: PostgreSQL at localhost:5432
- **AMQP**: Artemis MQ at localhost:5672
- **Dev Services**: Disabled (using external containers)

## Prerequisites

Before starting Horreum, ensure these services are running:

1. **PostgreSQL** container on port 5432
2. **Artemis MQ** container on port 5672

Check with:
```bash
lsof -i :5432  # PostgreSQL
lsof -i :5672  # Artemis
```

## Start Commands

### Option 1: Full Stack (Backend + Frontend integrated)

```bash
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
mvn quarkus:dev -pl 'horreum-backend'
```

Access at: http://localhost:8080

### Option 2: Frontend Separately (for frontend development)

**Terminal 1 - Backend:**
```bash
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
mvn quarkus:dev -pl 'horreum-backend' -Dquarkus.quinoa.enabled=false -Dquarkus.test.continuous-testing=disabled
```

**Terminal 2 - Frontend:**
```bash
cd horreum-web && npm run dev
```

Access at: http://localhost:3000

## Login Credentials

- **Username**: `horreum.bootstrap`
- **Password**: `secret`

## Configuration File

Environment config is in: `horreum-backend/.env`

Key settings:
- `horreum.roles.provider=database` - Use database auth
- `quarkus.oidc.tenant-enabled=false` - Disable Keycloak
- `horreum.dev-services.enabled=false` - Use external containers

## Useful Scripts

| Script | Purpose |
|--------|---------|
| `scripts/run/run-horreum-dev.sh` | Quick start dev mode |
| `scripts/run/start-backend-final.sh` | Start backend only |
| `scripts/run/start-frontend-final.sh` | Start frontend only |
| `scripts/data/import-data.sh` | Import example data |
| `scripts/utils/verify-database.sh` | Verify database tables |

## Troubleshooting

### Port already in use
```bash
lsof -i :8080
kill -9 <PID>
```

### Java version issues
```bash
java -version  # Should be 17
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.17/libexec/openjdk.jdk/Contents/Home
```

### Database connection failed
Check PostgreSQL container is running on port 5432.
