# Plan: Implementation Roadmap

## Phase 0 — Setup (0.5 day)
- [x] Repo scaffold (`src/`, `terraform/`, `.github/workflows/`, `tests/`)
- [x] Terraform remote backend (S3 + DynamoDB lock) — validated against Floci
- [x] GitHub OIDC provider + IAM role (trust policy scoped to repo/branch) — Terraform valid, apply requires real AWS

## Phase 1 — Core Infra (1 day)
- [x] Terraform: DynamoDB table
- [x] Terraform: Lambda module (least-priv IAM role per function)
- [x] Terraform: API Gateway REST + routes + IAM/Cognito authorizer
- [x] Lambda Powertools integration (logs/metrics/tracing)

## Phase 2 — Application Code (1 day)
- [x] CRUD handlers (Python), input validation (pydantic)
- [x] Structured logging, X-Ray subsegments
- [x] Unit tests (pytest, moto for AWS mocks)

## Phase 3 — DevSecOps Pipeline (1-1.5 day)
- [x] GH Actions: lint (ruff) + unit tests
- [x] GH Actions: SAST (Bandit)
- [x] GH Actions: SCA (pip-audit) + Dependabot config
- [x] GH Actions: IaC scan (Checkov)
- [x] GH Actions: secrets scan (gitleaks)
- [x] GH Actions: terraform plan (PR) → apply (main, manual approval env protection)
- [x] Branch protection: required checks before merge (script ready — run `scripts/branch-protection.sh` after `gh auth login`)

## Phase 4 — Zero-Trust Deploy Hardening (0.5 day)
- [x] Confirm no static keys anywhere (grep + gitleaks history scan)
- [x] Document OIDC trust policy conditions (`sub`, `aud`)
- [x] Separate dev/prod IAM roles, environment protection rules in GH

## Phase 5 — Observability & Cost (0.5 day)
- [ ] CloudWatch dashboard (errors, duration, throttles)
- [ ] X-Ray trace review, cold start measurement
- [ ] Cost estimate doc (low-traffic assumptions)

## Phase 6 — Polish for Portfolio (0.5 day)
- [ ] README: architecture diagram, threat model, run instructions
- [ ] Postman/curl examples
- [ ] "Lessons learned / tradeoffs" section (recruiter-facing)

## Milestones
1. Infra + API deployed manually (end Phase 1)
2. CRUD working end-to-end (end Phase 2)
3. Full pipeline green with all scans (end Phase 3)
4. Zero-trust confirmed, no keys (end Phase 4)
5. Portfolio-ready repo (end Phase 6)

**Total estimate**: ~4.5-5.5 days