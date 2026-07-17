# Spec: Serverless REST API PoC — AWS Lambda Best Practices & Innovation

## 1. Goal
PoC showing DevSecOps best practices + innovative patterns on AWS Lambda.

## 2. Scope
REST API backend, Python runtime, Terraform IaC, GitHub Actions CI/CD.

## 3. Architecture
- **API**: API Gateway (REST) → Lambda (Python 3.13, per-route functions)
- **Data**: DynamoDB (on-demand)
- **Auth**: IAM authorizer / Cognito (JWT) for API Gateway
- **CI/CD → AWS**: GitHub OIDC provider, no static AWS keys, short-lived STS role per environment (dev/prod)
- **Secrets**: AWS Secrets Manager / SSM Parameter Store (no plaintext secrets, no .env in repo)
- **Observability**: CloudWatch Logs (structured JSON), X-Ray tracing, Lambda Powertools (metrics/logs/tracing)

## 4. Security Requirements (DevSecOps pipeline)
| Stage | Tool |
|---|---|
| SAST | Bandit / Semgrep |
| SCA (deps) | pip-audit / Dependabot / Snyk |
| IaC scan | Checkov / tfsec |
| Secrets scan | gitleaks |
| Container/artifact scan (if used) | Trivy |
| Policy-as-code | OPA / Terraform Sentinel (optional, stretch) |
| Least privilege | one IAM role per Lambda, scoped to exact resources |

All scans run as required GitHub Actions checks, block merge on fail (severity threshold configurable).

## 5. Innovative Angle
Zero-trust deployment: **no long-lived AWS credentials anywhere** — GitHub OIDC → assume-role → deploy. Document trust policy, session duration, condition keys (`aud`, `sub` repo/branch restriction).

## 6. Non-Functional Requirements
- Infra fully reproducible via `terraform apply` (remote state in S3 + DynamoDB lock table)
- Cold start budget documented, provisioned concurrency discussed as tradeoff
- Cost estimate (Lambda + API GW + DynamoDB, low traffic tier)
- Unit tests (pytest) + integration test hitting deployed API in CI

## 7. Out of Scope (v1)
GraphQL, multi-account org, custom domain/Route53, WAF (documented as future work).

## 8. Deliverables
- `terraform/` modules (network optional, api-gateway, lambda, dynamodb, iam-oidc)
- `src/` Lambda handlers
- `.github/workflows/` (lint/test/scan, plan, apply)
- `README.md` with architecture diagram, threat model summary, how-to-run