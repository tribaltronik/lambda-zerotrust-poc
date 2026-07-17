# lambda-zerotrust-poc

Zero-trust serverless REST API on AWS — PoC demonstrating DevSecOps best practices, least-privilege IAM, and GitHub OIDC deployment with no long-lived credentials.

![Architecture](docs/architecture.png)

## What This Project Shows

- **Zero-trust CI/CD**: GitHub Actions assumes an AWS IAM role via OIDC — no static keys, no secrets in GitHub
- **Least-privilege IAM**: Each Lambda function gets its own IAM role scoped to a single DynamoDB action on a single table
- **DevSecOps pipeline**: SAST (Bandit), SCA (pip-audit), IaC scan (Checkov), secrets scan (gitleaks) — all blocking CI checks
- **Observability**: Lambda Powertools for structured logging, X-Ray tracing, and CloudWatch metrics
- **Fully reproducible infra**: Terraform modules with remote state in S3 + DynamoDB lock table

## Architecture

```
Client ──HTTPS──▶ API Gateway (REST) ──▶ Lambda (Python 3.13) ──▶ DynamoDB (on-demand)
                       │                         │
                       │ validate JWT            ├── CloudWatch Logs (structured JSON)
                       ▼                         ├── X-Ray Tracing
                  Cognito User Pool              └── CloudWatch Metrics
                                                     (Powertools)
```

**Routes:**

| Method | Path | Lambda | DynamoDB Action |
|--------|------|--------|-----------------|
| GET | `/items` | `list_items` | Scan, Query |
| GET | `/items/{id}` | `get_item` | GetItem |
| POST | `/items` | `create_item` | PutItem |
| PUT | `/items/{id}` | `update_item` | UpdateItem |
| DELETE | `/items/{id}` | `delete_item` | DeleteItem |

## Security Model

### Zero-Trust Deployment

No long-lived AWS credentials exist anywhere in this repo or in GitHub. The CI/CD pipeline uses **GitHub OIDC federation**:

1. GitHub Actions requests an OIDC token
2. AWS STS validates the token against the OIDC provider
3. STS assumes a short-lived IAM role (scoped to the repo, branch, and environment)
4. Terraform uses the temporary credentials to deploy

Trust policy conditions restrict access to:
- `repo:<org>/<repo>:*` — only this repository
- `aud: sts.amazonaws.com` — only for STS

### Least-Privilege IAM

Each Lambda function has:
- **Its own IAM role** (no shared roles)
- **One custom policy** with a single DynamoDB action scoped to the table ARN
- **AWSLambdaBasicExecutionRole** for CloudWatch Logs
- **AWSXRayDaemonWriteAccess** for X-Ray tracing

## Prerequisites

- Docker (Floci runs as a container)
- Python 3.13+
- Terraform >= 1.10
- Make

## Quick Start — Local Development

```bash
# 1. Start Floci (local AWS emulator) and deploy infrastructure
make up

# 2. Verify everything works
curl http://localhost:4566/restapis/<api_id>/dev/_user_request_/items \
  -H "Authorization: test"

# 3. When done, tear down
make down
```

### What `make up` Does

1. Starts Floci Docker container (emulates AWS on port 4566)
2. Runs `scripts/build-lambda.sh` to package Lambda functions with dependencies
3. Runs `terraform init` and `terraform apply` against Floci

### Useful Commands

```bash
make help              # Show all targets
make floci-status      # Check Floci container
make floci-health      # Health check
make build-lambdas     # Rebuild Lambda packages
make tf-plan           # Preview Terraform changes
make tf-apply          # Apply Terraform changes
make lint              # Run ruff linter
make test              # Run pytest
make clean             # Remove caches and build artifacts
```

## Deploy to AWS

> **Requires**: AWS account, GitHub repository, OIDC provider configured

```bash
# Set variables
export TF_VAR_github_org="your-org"
export TF_VAR_github_repo="your-repo"

# Initialize (uses S3 remote backend)
cd terraform && terraform init

# Plan
terraform plan -var="use_localstack=false" -var-file=terraform.tfvars.example

# Apply (requires manual approval in production)
terraform apply -var="use_localstack=false" -var-file=terraform.tfvars.example
```

### GitHub Actions CI/CD

The pipeline runs on every push/PR:

```
PR opened → lint + tests + security scans → terraform plan → review
     ↓
merge to main → terraform apply (manual approval required)
```

Required GitHub repository settings:
- Environments: `dev` (auto-deploy) and `prod` (manual approval)
- Branch protection: require status checks before merge

## Project Structure

```
├── src/
│   ├── handlers/              # Lambda function handlers
│   │   ├── list_items.py
│   │   ├── get_item.py
│   │   ├── create_item.py
│   │   ├── update_item.py
│   │   └── delete_item.py
│   └── shared/
│       └── config.py          # Powertools singletons (Logger, Tracer, Metrics)
├── terraform/
│   ├── modules/
│   │   ├── api-gateway/       # REST API, Cognito authorizer, routes
│   │   ├── lambda/            # Function + least-priv IAM role
│   │   └── dynamodb/          # Table (on-demand, PK/SK)
│   ├── provider.tf            # Floci-aware AWS provider
│   ├── oidc.tf                # GitHub OIDC (skipped on Floci)
│   ├── lambda.tf              # 5 Lambda module wirings
│   └── ...
├── scripts/
│   └── build-lambda.sh        # Build packages with pip dependencies
├── tests/
│   ├── unit/
│   └── integration/
├── .github/workflows/         # CI/CD pipelines
├── docs/
│   ├── spec.md                # Project specification
│   ├── plan.md                # Implementation roadmap
│   ├── architecture.dot       # Graphviz source
│   └── architecture.png       # Architecture diagram
├── decisions.md               # Architectural decision log
├── Makefile                   # Infrastructure lifecycle commands
└── pyproject.toml             # Python project config
```

## Tradeoffs & Lessons Learned

### Why Floci (not LocalStack)?
LocalStack Community was sunset in March 2026 and now requires auth tokens. Floci is free, MIT-licensed, and wire-compatible with LocalStack's API.

### Why Per-Function IAM Roles?
Shared roles violate least-privilege. If `list_items` is compromised, the attacker can only Scan/Query — not PutItem or DeleteItem.

### Why Pre-Built Lambda Zips?
Terraform's `archive_file` only zips the source directory. Python dependencies (aws-lambda-powertools, aws-xray-sdk, pydantic) must be pip-installed into the package. `scripts/build-lambda.sh` handles this.

### Lambda Cold Starts
With dependencies bundled, cold starts are ~2-5s on Floci. In production AWS, Python 3.13 cold starts are typically <1s. Provisioned concurrency can eliminate cold starts for critical paths.

### Floci Limitations
- Account ID must be 12 digits (`000000000000`)
- `UpdateAuthorizer` returns HTTP 405 (workaround: `terraform state rm` + re-apply)
- Tags not persisted on resources (cosmetic drift only)
- OIDC provider creation not supported

## License

MIT
