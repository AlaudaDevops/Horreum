# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Horreum is a performance results repository and regression analysis service built with:
- **Backend**: Quarkus (Java 17), PostgreSQL, Apache Artemis messaging
- **Frontend**: React (TypeScript), PatternFly UI components, Vite build system
- **Frontend Integration**: Quinoa (Quarkus extension for serving the React app)
- **API**: OpenAPI-based REST services with generated client code

## Build Commands

### Full Build and Run
```bash
# Build entire project (includes tests)
mvn clean install

# Run development server with backend + frontend
mvn quarkus:dev -pl 'horreum-backend'

# Build without tests (faster)
mvn -DskipTests=true -DskipITs install
mvn -Dquarkus.test.continuous-testing=disabled quarkus:dev -pl 'horreum-backend'
```

### Code Formatting
Code style is strictly enforced using Eclipse formatter:
```bash
# Format code (runs automatically during build)
mvn formatter:format impsort:sort

# Check formatting without full build
mvn process-sources

# Clean with node cache removal (for troubleshooting)
mvn clean -p remove-node-cache
```

### Testing
```bash
# Run unit tests
mvn test

# Run integration tests
mvn verify

# Run tests for specific module
mvn test -pl 'horreum-backend'

# Run single test class
mvn test -Dtest=ClassName

# Run single test method
mvn test -Dtest=ClassName#methodName
```

### OpenAPI Generation
After building, the OpenAPI specification is available at:
```
./horreum-api/target/generated/openapi.yaml
```

### Load Example Data
```bash
./infra-legacy/example-configuration.sh
```

## Architecture

### Module Structure
- **horreum-api**: OpenAPI definitions and Java interface contracts (Java 11 for Jenkins plugin compatibility)
- **horreum-client**: Generated API client library
- **horreum-backend**: Quarkus backend application with all service implementations
- **horreum-web**: React/TypeScript frontend (served via Quinoa)
- **horreum-integration-tests**: End-to-end integration tests
- **infra/**: Dev services configuration and deployment infrastructure

### Backend Architecture

The backend follows a layered service-oriented architecture:

**Service Layer** (`horreum-backend/src/main/java/io/hyperfoil/tools/horreum/svc/`):
- Core business logic in `*ServiceImpl` classes (e.g., `RunServiceImpl`, `DatasetServiceImpl`)
- Services implement interfaces defined in `horreum-api/src/main/java/io/hyperfoil/tools/horreum/api/services/`
- Services are CDI `@ApplicationScoped` beans
- Security enforced via JAX-RS annotations (`@RolesAllowed`, `@PermitAll`)
- Key services:
  - `RunService`: Performance test run management
  - `DatasetService`: Dataset storage and transformation
  - `SchemaService`: JSON schema management and validation
  - `TestService`: Test definition and configuration
  - `AlertingService`: Change detection and notifications
  - `ExperimentService`: A/B testing and comparisons

**Entity/DAO Layer** (`horreum-backend/src/main/java/io/hyperfoil/tools/horreum/entity/`):
- Hibernate entities organized by domain (e.g., `data/`, `alerting/`, `user/`)
- DAO interfaces extend Quarkus Panache patterns
- Database schema managed via Liquibase (`horreum-backend/src/main/resources/db/changeLog.xml`)

**Messaging** (`horreum-backend/src/main/java/io/hyperfoil/tools/horreum/bus/`):
- Async processing via SmallRye Reactive Messaging with Apache Artemis
- Key channels: `dataset-event`, `run-recalc`
- Event-driven architecture for dataset transformations and change detection

**Other Key Packages**:
- `action/`: Pluggable action system for notifications (webhooks, GitHub issues, etc.)
- `changedetection/`: Statistical change detection algorithms
- `experiment/`: A/B test evaluation
- `mapper/`: Jackson JSON mappers
- `server/`: JAX-RS configuration and filters

### Frontend Architecture

The frontend is a React SPA with TypeScript:

**Structure** (`horreum-web/src/`):
- `components/`: Reusable PatternFly-based React components
- `domain/`: Feature modules (tests, runs, schemas, alerting, reports, admin, user)
- `services/`: API client wrappers using `fetchival`
- `auth/`: OIDC authentication with react-oidc-context
- `context/`: React Context providers for global state

**API Integration**:
- Backend REST API at `/api/*`
- Type-safe API calls via generated TypeScript definitions
- OpenAPI spec drives both Java and TypeScript code generation

**Build System**:
- Vite for fast HMR and bundling
- Dev server runs on port 3000, proxied through Quarkus
- Quinoa manages build integration between Quarkus and Node.js

### Configuration

Main config: `horreum-backend/src/main/resources/application.properties`
- Database connection (PostgreSQL)
- AMQP messaging (Apache Artemis)
- Keycloak authentication
- Quinoa/frontend integration

Environment overrides via `.env` file in `horreum-backend/` (e.g., for production database backups).

### Authentication & Authorization

- Keycloak-based OIDC/OAuth2
- Default dev credentials: `horreum.bootstrap` / `secret`
- Access Keycloak admin: `curl -s http://localhost:8080/api/config/keycloak | jq -r .url`
- Role-based access control enforced at service layer

### Database

- PostgreSQL 13+ required
- Liquibase migrations in `horreum-backend/src/main/resources/db/changeLog.xml`
- Row-level security policies in `horreum-backend/src/main/resources/db/policies.sql`
- Can use existing database backup via `horreum.dev-services.postgres.database-backup` property

## Development Workflow

1. **Making Changes**: Always format code before committing (happens automatically during build)
2. **API Changes**: If modifying API contracts, regenerate OpenAPI and ensure clients update
3. **Database Changes**: Add Liquibase changesets to `changeLog.xml`, never modify existing ones
4. **Frontend Changes**: Hot reload works via Vite dev server on port 3000
5. **Testing**: Run full test suite before submitting PRs (`mvn install`)

## Common Development Tasks

### Running with Podman (instead of Docker)
```bash
# Terminal 1: Start Podman socket
podman system service -t 0

# Terminal 2: Set environment and run
export DOCKER_HOST=unix:///run/user/${UID}/podman/podman.sock
mvn quarkus:dev -pl 'horreum-backend'
```

### Using Production Database Backup
Place a `.env` file in `horreum-backend/`:
```
horreum.dev-services.postgres.database-backup=<path/to/db>
horreum.dev-services.keycloak.db-password=<password>
quarkus.datasource.username=<username>
quarkus.datasource.password=<password>
quarkus.liquibase.migration.migrate-at-start=false
```

### Backporting to Stable Branch
Add `backport` or `backport-squash` label to PR:
- `backport`: Preserves all commits (don't delete source branch until backport PR created)
- `backport-squash`: Uses merge commit SHA only

## Key Implementation Patterns

1. **Service Implementation**: Services in `horreum-backend/svc/` implement interfaces from `horreum-api/services/`
2. **Security**: Use `@RolesAllowed` annotations on service methods, roles defined in `Roles.java`
3. **Transactions**: Quarkus manages transactions; use `@Transactional` when needed
4. **Messaging**: Emit events via `@Channel` for async processing
5. **Error Handling**: Use `ServiceException` for business logic errors (maps to HTTP responses)
6. **Frontend API Calls**: Use the generated API client wrappers in `horreum-web/src/services/`

## Platform Support

Tested on Linux (Fedora, RHEL), Windows/WSL2, and macOS 13.3+ (M2 hardware).

## Version Information

Current version: 0.20-SNAPSHOT
Pre-1.0 software: API breaking changes may occur between minor versions (per semver clause 4).
