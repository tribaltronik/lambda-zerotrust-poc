# Decisions Log

## Format
Each entry: **Date** — **Decision** — **Rationale** — **Tradeoffs**

---

## Phase 0 — Setup

### 2026-07-17 — Use Floci for local AWS emulation
- **Decision**: Use Floci (free, MIT-licensed) instead of LocalStack for local AWS emulation
- **Rationale**: LocalStack Community sunset in March 2026 requires auth tokens. Floci is free forever, no auth tokens, MIT licensed, 68 AWS services, ~24ms startup
- **Tradeoffs**: Floci is newer (Feb 2026) so less community content; but wire-compatible with LocalStack so migration is trivial

### 2026-07-17 — Terraform AWS provider ~> 6.0
- **Decision**: Use AWS provider version constraint `~> 6.0`
- **Rationale**: Latest stable (6.30.0), Floci compatibility tests use this version
- **Tradeoffs**: None significant

### 2026-07-17 — Python 3.13 runtime
- **Decision**: Target Python 3.13 for Lambda handlers
- **Rationale**: Latest stable Python, Floci supports it natively via public.ecr.aws/lambda/python:3.13
- **Tradeoffs**: Some Lambda runtime features may lag behind older versions

### 2026-07-17 — Remove `prevent_destroy` from state bucket
- **Decision**: Remove `lifecycle { prevent_destroy = true }` from S3 state bucket
- **Rationale**: In local Floci development, state is ephemeral. `prevent_destroy` blocks `terraform destroy` during iteration. For real AWS, re-add before production.
- **Tradeoffs**: Risk of accidental state bucket deletion in real AWS (mitigated by re-adding before prod deploy)

### 2026-07-17 — Floci does not emulate `CreateOpenIDConnectProvider`
- **Decision**: `aws_iam_openid_connect_provider` Terraform is valid (`terraform validate` passes) but `terraform apply` fails against Floci with `UnsupportedOperation`
- **Rationale**: OIDC provider creation is an AWS-specific federation operation not implemented in Floci. IAM roles, S3, DynamoDB all work fine.
- **Tradeoffs**: OIDC trust policy can only be tested against real AWS. Documented as CI/CD validation in Phase 3/4. Workaround: use `-target` to exclude OIDC provider during local `terraform apply`.

---

## Phase 1 — Core Infra

### 2026-07-17 — Floci account ID must be 12 digits
- **Decision**: Set `FLOCI_DEFAULT_ACCOUNT_ID` to `000000000000` (12 zeros) instead of `00000000000` (11 zeros)
- **Rationale**: AWS account IDs are 12 digits. Terraform AWS provider 6.x validates ARNs against regex `^\d{12}$`. Floci was using 11 digits, causing `InvalidParameterValueException` on all IAM role ARNs.
- **Tradeoffs**: None — this is a Floci configuration fix, not a design decision

### 2026-07-17 — Per-function handler paths in lambda module
- **Decision**: Pass explicit `handler` variable for each Lambda function (e.g., `list_items.lambda_handler`) instead of using the module default `handler.lambda_handler`
- **Rationale**: Each handler file is named after its operation (e.g., `list_items.py`), not a generic `handler.py`. The module's `archive_file` data source zips the entire `src/handlers/` directory, so handler path must match the filename.
- **Tradeoffs**: Slightly more verbose in `lambda.tf` but each function is self-documenting

### 2026-07-17 — Floci does not support UpdateAuthorizer
- **Decision**: Accept that `terraform apply` will fail on `aws_api_gateway_authorizer` updates against Floci. Workaround: remove authorizer from state (`terraform state rm`) and let Terraform recreate it on next apply.
- **Rationale**: Floci returns HTTP 405 for `UpdateAuthorizer` API calls. The authorizer is correctly configured on first creation. Subsequent config changes to `provider_arns` trigger an update that Floci can't handle.
- **Tradeoffs**: Extra manual step when changing Cognito User Pool ARN locally. Not an issue in real AWS.

### 2026-07-17 — Lambda packaging: pre-built zips with dependencies
- **Decision**: Use `scripts/build-lambda.sh` to create deployment packages that include pip-installed dependencies, instead of Terraform's `archive_file` which only zips the source directory.
- **Rationale**: `archive_file` with `source_dir` only includes files in that directory. Python dependencies (aws-lambda-powertools, aws-xray-sdk, pydantic) must be bundled into the zip for the Lambda runtime to import them.
- **Tradeoffs**: Requires `make build-lambdas` before `terraform apply`. Adds a `.build/` directory. For CI/CD, this runs in the GH Actions workflow.

### 2026-07-17 — aws-xray-sdk required by Powertools Tracer
- **Decision**: Include `aws-xray-sdk` in Lambda deployment packages alongside `aws-lambda-powertools`.
- **Rationale**: `from aws_lambda_powertools import Tracer` fails at cold-start with `No module named 'aws_xray_sdk'` unless the SDK is in the package.
- **Tradeoffs**: Adds ~17MB per Lambda zip. Can reduce by using Powertools without Tracer or using Lambda Layers.
