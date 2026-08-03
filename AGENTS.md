# AGENTS.md

Serverless REST API PoC on AWS (Python 3.13, Terraform, GitHub Actions). Python/Terraform are the code; the toolchain is **Floci** (local AWS emulator, port 4566) + GitHub OIDC for real deploys.

## Local dev flow (order matters)

```bash
# one-time, creates the remote-state S3 bucket + lock table via terraform/bootstrap/
make floci-up && make tf-bootstrap
# every subsequent run:
make up                 # floci-up + build-lambdas + tf-init + tf-apply
make tf-plan            # plan against Floci
make test               # pytest (69 unit tests, moto mocks)
make lint               # ruff (line-length 120)
```

- Backend is **S3**, not local. `make tf-init` targets Floci (`backend-floci.tfvars`); `make tf-init-aws` targets real AWS (`backend-aws.tfvars`). Running `terraform init` without `-backend-config` fails.
- `make build-lambdas` MUST run before `terraform apply`: Lambda zips are pre-built with pip dependencies by `scripts/build-lambda.sh`. Terraform's `archive_file` would not bundle `aws-lambda-powertools`/`aws-xray-sdk`/`pydantic`.
- State bucket + lock table live in a **separate `terraform/bootstrap/` module** — the main config must NOT manage them.

## Verification / scans

Run from repo root; bandit & pip-audit are in `.venv`, checkov/gitleaks/actionlint are global:

```bash
.venv/bin/bandit -r src -ll -q
.venv/bin/pip-audit -r requirements-lambda.txt
checkov -d terraform --config-file .checkov.yml   # baseline skips are intentional, see .checkov.yml
gitleaks detect --source . --redact              # also `gitleaks git` for history
actionlint .github/workflows/*.yml               # workflow lint, no Docker needed
```

Full `act` rehearsal requires Docker (may not be running). `actionlint` + running the scan commands locally is the fallback verification.

## Floci quirks (decisions.md has full details)

- Does **not** emulate OIDC provider creation — `oidc.tf` skips it when `use_localstack=true`; OIDC trust policy is only testable on real AWS.
- `UpdateAuthorizer` returns HTTP 405 → workaround is `terraform state rm` + re-apply.
- Tags not persisted; account ID must be `000000000000` (12 digits).

## Terraform structure

- `modules/{api-gateway,lambda,dynamodb}`; `oidc.tf` (GitHub Actions role), `lambda-permissions.tf` (API GW→Lambda invoke), `lambda.tf` wires the 5 handlers.
- `use_localstack` var (default true) switches provider endpoints + OIDC provider on/off. Set it via `TF_VAR_use_localstack=false` or tfvars for real AWS.
- `.gitignore` ignores `*.tfvars` EXCEPT `terraform/backend-*.tfvars` and `*.tfvars.example`.
- `github_org`/`github_repo` tfvars must match the real repo for OIDC `sub` to work.

## Lambda / tests

- Handlers: `src/handlers/<route>.py`, entrypoint `lambda_handler`. Shared Powertools singletons in `src/shared/config.py`.
- pytest `pythonpath = ["src"]` is set in `pyproject.toml` — tests import handlers directly.
- Security posture: per-function IAM roles, no hardcoded creds, `.env` gitignored (`.env.example` committed and must stay secret-free).

## CI/CD

- 4 workflows: `ci.yml`, `security.yml` (sast/sca/iac/secrets), `terraform-plan.yml` (PR), `terraform-apply.yml` (main, `environment: dev`).
- `terraform-plan.yml` deliberately has **no `paths` filter** so "Terraform plan (dev)" can be a required PR check.
- Required PR checks (see `scripts/branch-protection.sh`): Lint & unit tests, SAST, SCA, IaC, Secrets, Terraform plan.
- **Known gap (Phase 4 pending)**: `aws_iam_role.github_actions` in `oidc.tf` has a trust policy but **no permissions policy** — CI cannot deploy yet. Its `sub` condition currently allows any branch (`repo:org/repo:*`).

## References

`docs/spec.md` (scope/NFRs) · `docs/plan.md` (roadmap, phase checkboxes) · `decisions.md` (ADR log, incl. Floci quirks and packaging rationale).
