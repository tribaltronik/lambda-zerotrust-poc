# Threat Model

A lightweight, portfolio-grade threat model for the zero-trust serverless PoC:
a Cognito-protected REST API backed by DynamoDB, deployed to AWS exclusively
through GitHub OIDC-federated Terraform. It follows the classic STRIDE-lite
frame: enumerate assets and trust boundaries, then map each threat to the
mitigation actually shipped in this repo — and be honest about what is still
open.

## Assets

| Asset | Location |
|---|---|
| DynamoDB items table | `terraform/dynamodb.tf` (on-demand, PITR) |
| Terraform remote state | S3 bucket + DynamoDB lock table, `terraform/bootstrap/` |
| IAM roles (5 Lambda + dev/prod GitHub Actions) | `terraform/modules/lambda/main.tf`, `terraform/oidc.tf` |
| Cognito User Pool + client | `terraform/cognito.tf` |
| API / Lambda code | `src/handlers/` (packaged by `scripts/build-lambda.sh`) |
| GitHub variables/secrets + CI/CD pipeline | `.github/workflows/`, repo `AWS_ROLE_ARN` var |

## Trust boundaries

- **Client ↔ API Gateway edge** — TLS + Cognito JWT authorizer
  (`terraform/modules/api-gateway/main.tf:61-69`)
- **API Gateway → Lambda** — `AWS_PROXY` integration + `aws_lambda_permission`
  restricted to the API ARN (`terraform/lambda-permissions.tf`)
- **Lambda → DynamoDB** — least-privilege IAM, one action per function
  (`terraform/lambda.tf`)
- **Developer → GitHub** — branch protection + required reviews + required
  security checks (`scripts/branch-protection.sh`)
- **CI → AWS** — GitHub OIDC → `sts:AssumeRoleWithWebIdentity`, no static keys
  (`terraform/oidc.tf`)

## Threats

| Threat | Vector | Impact | Mitigation in place | Residual risk |
|---|---|---|---|---|
| Unauthenticated API abuse | Direct request with no/invalid JWT | Route bypass, data exposure | All 5 methods use `authorization = "COGNITO_USER_POOLS"` with a Cognito authorizer; TLS at edge | Weak-password accounts (see below) |
| Privilege escalation via a compromised Lambda | Malicious dependency / exploited handler uses its own role to pivot | Access to other AWS services | Per-function roles, one DynamoDB action on one table ARN (`terraform/modules/lambda/main.tf:70-78`); no `iam:*`/`sts:AssumeRole` on Lambda roles | Compromised function still reads its own data + logs |
| Cross-function data access | Function A calls an action it shouldn't (Scan/Put/Delete) | Data corruption across routes | Actions scoped per route: Scan/Query, GetItem, PutItem, UpdateItem, DeleteItem (`terraform/lambda.tf`) | Shared table — no row-level authz, so `delete_item` can delete any item |
| Stolen/malicious PR running terraform against prod | Malicious PR / leaked token assumed by the plan job | Prod infra changes, resource exfiltration | prod role `sub` pinned to `refs/heads/main` (`terraform/oidc.tf:27-29`); PRs match only the dev role; apply gated by `environment: dev` manual approval + branch protection | Dev resources remain at risk from any merged PR |
| Leaked OIDC token replay | Token exfiltrated from a runner, replayed elsewhere | Mint AWS creds as dev/prod role | `aud = sts.amazonaws.com` binds the token to STS; `max_session_duration = 3600` (`terraform/oidc.tf:212-223`); `sub` pins repo + ref | Within the 1h window a leaked dev token can plan/apply on dev |
| Supply chain | Malicious pip / GH Action / Terraform provider dependency | RCE in build or Lambda runtime | Dependabot (Python, Actions, Terraform); pip-audit in CI; pinned deps + lockfiles | Transitive deps not fully audited; cadence depends on Dependabot |
| Terraform state tampering | Direct S3/DynamoDB access, or leaked state creds | Planted infra, corrupt state, lock DoS | S3 versioning + SSE, DynamoDB lock table (`terraform/bootstrap/`); GitHub role policy scoped to the exact bucket/key prefix + lock table (`terraform/oidc.tf:40-55`) | No backup/rotation policy; recovery relies on versioning |
| Secrets in code | Hardcoded creds/tokens committed | Long-lived creds leaked in git history | gitleaks tree + history scan blocks merge; `.env` gitignored, `.env.example` secret-free | History scan only catches known patterns; requires rotate-on-find |
| Noisy / denial (throttling) | Bot/scripted high-volume requests at the edge | Cost burn, DynamoDB throttling, 429s | API GW default throttles; on-demand capacity absorbs spikes | No WAF rate limits or budget alarms yet |

## Residual risks / out of scope

- **No WAF / rate limiting** — the API Gateway is public with no AWS WAF rules
  or per-key rate limits (spec.md §7; `.checkov.yml` CKV2_AWS_29/51). No cost
  guardrails (budget alarms) either.
- **No mutual-TLS client certs** — the only client identity is the Cognito JWT
  (`.checkov.yml` CKV2_AWS_51).
- **No VPC** — Lambdas run on the serverless-managed runtime, not inside a VPC
  (`.checkov.yml` CKV_AWS_117), so there is no SG/subnet-level isolation.
- **Cognito default password policy** — minimum 8 chars, no required symbols
  (`terraform/cognito.tf:7-13`); no advanced account-takeover protection.
- **In-handler request validation** — API GW request-model validation is off
  (`.checkov.yml` CKV2_AWS_53); pydantic validates in the handlers, so malformed
  input costs an invocation.
- **Uncapped Lambda log retention** — API GW access logs retain 365 days
  (`terraform/modules/api-gateway/main.tf:106-111`), but the Lambda function log
  groups use the account default (never expire), so log cost grows unbounded.
- **Pending one-time OIDC bootstrap** — the OIDC provider + dev/prod roles exist
  in `terraform/oidc.tf`, but the real AWS provider must still be provisioned
  (`TF_VAR_use_localstack=false terraform apply`) and the repo `AWS_ROLE_ARN`
  variable set before CI can deploy (see README → Deploy to AWS).
