---
name: horreum-import
description: Import example data into Horreum. Use when user wants to load test data, import examples, or populate Horreum with sample data.
---

# Import Horreum Data

Import example data into a running Horreum instance.

## Prerequisites

Horreum must be running at http://localhost:8080

## Import Command

Using Basic Auth:
```bash
./scripts/data/example-configuration-basic-auth.sh
```

Or with curl directly:
```bash
curl -u horreum.bootstrap:secret http://localhost:8080/api/test
```

## Credentials

- **Username**: `horreum.bootstrap`
- **Password**: `secret`

## What Gets Imported

| Type | Count | Description |
|------|-------|-------------|
| Schemas | 3 | Hyperfoil, ACME Benchmark, ACME Horreum |
| Tests | 2 | Protected Test, Roadrunner Test |
| Runs | 1 | Sample benchmark run |
| Labels | 2 | Test Label, Throughput Label |
| Transformers | 1 | ACME Transformer |
| Actions | 2 | HTTP webhook actions |

## Verify Import

After import, check:
- http://localhost:8080 -> Tests (should show 2 tests)
- http://localhost:8080 -> Schemas (should show 3 schemas)

## Data Files Location

Example data files are in:
```
infra-legacy/example-data/
```
