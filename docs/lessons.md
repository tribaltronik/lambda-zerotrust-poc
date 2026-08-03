# Lessons Learned & Tradeoffs

A recruiter-facing narrative of what this PoC set out to prove, the decisions
that made it real, and the honest tradeoffs behind them. Every claim below is
verifiable in this repo — file references and concrete numbers included.

## 1. TL;DR

This PoC is a zero-trust serverless REST API on AWS: five Python 3.13 Lambdas
behind API Gateway, backed by a single DynamoDB table, deployed entirely by
GitHub Actions that assume short-lived IAM roles via GitHub OIDC — **there are
no static AWS keys anywhere in the repo or in GitHub**. The biggest lessons are
about the seams the demo material doesn't show: tooling drift silently breaking
CI, a local dev environment masking a real runtime bug, and an IaC tool
(Floci) that is free but not a drop-in for real AWS. I'd also argue the single
best engineering decision here is per-environment, branch-scoped OIDC trust
policies — the thing that actually makes the "zero-trust" claim true.

## 2. What I'd build and why

The goal was a CRUD REST API that demonstrates production-grade AWS practice,
not just a working endpoint. Each layer was chosen to answer a specific "why":

- **API Gateway (REST) + Cognito JWT authorizer.** Auth lives at the edge, not
  in the handler. The authorizer validates the JWT before the Lambda is ever
  invoked (`terraform/modules/api-gateway/main.tf`), so unauthenticated traffic
  never consumes Lambda compute. Every method is `COGNITO_USER_POOLS` + proxy
  integration — no request mapping to maintain.
- **One Lambda per route, each with its own IAM role.** `list_items`, `get_item`,
  `create_item`, `update_item`, `delete_item` are five separate functions
  (`src/handlers/`), and each function's role carries exactly one DynamoDB
  action on exactly one table (`terraform/modules/lambda/main.tf`). If
  `list_items` is ever compromised, the attacker can Scan/Query — and nothing
  else. That's least privilege made structural.
- **A single DynamoDB table** with a hash/sort-key model, on-demand billing, and
  point-in-time recovery. One table keeps the blast radius and the bill tiny;
  the access pattern here (read-mostly, small items) doesn't need multiple
  tables or a hot partition.
- **Terraform modules with remote state** (S3 bucket + DynamoDB lock table in a
  separate `terraform/bootstrap/` module), so the whole stack is reproducible
  and safe to edit by more than one person.
- **A gated DevSecOps pipeline**: ruff + pytest, Bandit (SAST), pip-audit (SCA),
  Checkov (IaC), gitleaks (secrets, including git history), plus a Terraform
  plan posted to every PR. Merge is blocked until every check is green
  (`scripts/branch-protection.sh` enforces it).
- **Observability from day one**: Powertools structured JSON logs, X-Ray
  tracing active on both Lambda and the API Gateway stage, and a CloudWatch
  dashboard (`terraform/cloudwatch.tf`) that answers "is it broken, and why"
  without digging through raw logs.

## 3. Lessons learned

### 3.1 Unpinned tool versions will drift and break your CI

I installed Checkov unpinned. Months (or a release) later, CI started failing
with checks that hadn't existed when the baseline was written. The fix
(`.github/workflows/security.yml`): pin `checkov==3.2.470` and document every
new skip with the reason it's acceptable (`.checkov.yml` grew a "validated
against 3.2.470" section). This is a reproducible pipeline now — a lockstep
between the version and the baseline — instead of a moving target.

> **What I'd do differently:** pin early, and treat "new failing checks" as a
> deliberate review event, not a fire. A policy-as-code baseline that can't
> drift is only trustworthy if the version that produced it is recorded too.

### 3.2 Your local venv is a liar — clean-room CI catches what it hides

`src/shared/db.py` imported `mypy-boto3-dynamodb` (a type-only package) at
module top level. It was installed in my local venv, so everything passed
locally — but it wasn't declared in `pyproject.toml`, so CI's fresh install
failed with `ModuleNotFoundError`. Worse: because it isn't in
`requirements-lambda.txt`, the deployed Lambda would have crashed on its very
first cold start. The fix (commit `d392866`): move the import under
`TYPE_CHECKING` and declare the package in the dev extras.

> **What I'd do differently:** assume your machine is wrong until CI proves
> otherwise. I now treat "works on my machine" as a red flag and keep runtime
> vs. dev dependencies strictly separated (`requirements-lambda.txt` vs.
> `pyproject.toml` `[optional-dependencies].dev`).

### 3.3 OIDC trust policies: scope `sub` per environment, not just per repo

The whole "zero-trust" angle is the IAM role trust policies in
`terraform/oidc.tf`. Two roles, one per environment:
`lambda-zerotrust-poc-github-actions-dev` trusts `refs/heads/*` **and**
`refs/pull/*`; `lambda-zerotrust-poc-github-actions-prod` trusts
`refs/heads/main` only. Both require `aud = "sts.amazonaws.com"` (StringEquals),
so the token can only ever be redeemed at STS. The subtle part: IAM ORs the
patterns in a single `StringLike` list, so dev's one Statement covers both
branches and PRs. The payoff is real — a compromised PR or feature branch can
assume only the dev role; there is no code path from a PR to a prod deploy.

> **What I'd do differently:** keep the `sub` patterns as a single source of
> truth (they're in a `local` block here) and write an explicit threat test for
> "can this branch reach prod" before merging. On a bigger org I'd extend the
> same idea to environments, not just refs.

### 3.4 Terraform's `archive_file` cannot bundle pip dependencies — build the zips first

This is the least-obvious gotcha in the whole project. `archive_file` with
`source_dir` zips only your source directory — the Lambda runtime then fails
imports at cold start because `aws-lambda-powertools`, `aws-xray-sdk`, and
`pydantic` aren't there. The fix is `scripts/build-lambda.sh`: pip-install
deps into a staging dir, copy the handler + shared code, zip. It also taught me
that Powertools' `Tracer` *requires* `aws-xray-sdk` at import time — a
`No module named 'aws_xray_sdk'` crash you only hit in the runtime
(`decisions.md`, 2026-07-17), and it costs ~17 MB per zip.

> **What I'd do differently:** for a bigger project I'd move shared deps to a
> Lambda Layer or the `python3.13` managed image. For a PoC, pre-built zips are
> simpler and keep the build a plain `make` step.

### 3.5 Floci is free and fast, but it's an emulator, not AWS — plan for the seams

I chose Floci (MIT-licensed, free forever, ~24 ms startup, 68 services) after
LocalStack Community sunset in March 2026 and required auth tokens. It works
for the daily loop (`make up`), but it has hard seams I had to design around:
no OIDC provider creation (`UnsupportedOperation` — `oidc.tf` skips it when
`use_localstack=true`), `UpdateAuthorizer` returns HTTP 405 (workaround:
`terraform state rm` + re-apply), tags aren't persisted, and the account ID
must be the full 12 digits (`000000000000` — the provider regex rejects 11).

> **What I'd do differently:** budget for the parts that only work on real AWS
> (here: the OIDC federation flow itself). Floci is ideal for iterating on
> resources it emulates well; don't let it lull you into thinking the emulated
> config == production config.

### 3.6 Per-function IAM roles are cheap insurance that compounds

A shared role with five DynamoDB actions is less code. But the moment you have
one role per function, the permission surface becomes visible in code and
reviewable in a diff — and the "cost" of a new function is one tiny, obvious
statement instead of an audit of everything the shared role can do. I'd keep
this even if the app grew to dozens of functions (with a module making it
one-line to wire).

### 3.7 Instrument for "is it broken" before you scale anything

Structured logs alone don't tell you if you're slow or failing. The dashboard
(`terraform/cloudwatch.tf`) turns CloudWatch data into answers: p95 duration
per function, cold-start count parsed from `REPORT` lines
(`scripts/measure-cold-start.sh`), API Gateway 4XX/5XX, DynamoDB throttles.
Measured on Floci, cold starts look like 2–5 s — the docs (`README.md`,
`docs/observability.md`) explicitly warn those numbers aren't representative
of real AWS, where Python 3.13 init is typically tens of milliseconds. Knowing
*how* to read the trace (`requestId` → X-Ray segment correlation) matters more
than the raw latency.

### 3.8 Branch protection and environment gates are part of the security story

Deploys to `dev` wait on a manual approval (`environment: dev` in the apply
workflow); prod is set up for 2 required reviewers. And `terraform-plan.yml`
deliberately has **no `paths` filter**, so the plan check is always a required
PR gate — a tiny detail that keeps the pipeline honest when someone edits
infra "by accident".

## 4. Tradeoffs

Honest accounting of what I consciously gave up:

- **No WAF.** The API is public at the edge with only the Cognito authorizer
  in front. For a PoC with ~100k req/mo, the authorizer + TLS is proportionate;
  a WAF is the clear next step before real traffic (documented as out of scope
  in `docs/spec.md` §7).
- **No provisioned concurrency.** It eliminates cold starts but bills for idle
  warm capacity — at this traffic level the dashboard shows the cold-start tail
  is a non-event, so pay-per-invoke is the right call. The tradeoff is
  documented in `docs/cost.md` and `docs/observability.md` §4.
- **Single region (us-east-1).** No multi-region failover, no latency story
  outside the US. Correct for a PoC; the decision to stay regional (vs. edge
  via CloudFront) keeps the bill and the mental model small.
- **In-handler validation (pydantic) instead of API Gateway request models.**
  Validation lives in Python, which means the same models unit-test in pytest
  and run identically on Floci and AWS. The cost: the edge accepts garbage it
  then rejects inside the Lambda — a WAF/request-model fan would push this
  earlier.
- **AWS-managed KMS instead of a customer CMK.** Encryption is on for Lambda
  env vars, DynamoDB, and CloudWatch log groups, but with AWS-managed keys —
  no key-policy ceremony, no per-key cost, but also no key rotation/audit you
  control. Fine for a PoC; not fine for regulated workloads.
- **X-Ray 100% sampling vs. cost.** `tracing_mode = "Active"` traces every
  request — great for debugging, and it happens to sit exactly at the 100k
  free traces/month. A real workload would use rule-based sampling (~5%) to
  stay far below the free tier. The tension is visible in `docs/cost.md`: X-Ray
  is a top-two line item at steady state.
- **Pre-built zips vs. Lambda Layers.** Simpler build, but every function
  carries ~17 MB of shared deps and redeploys when *any* shared dep changes.
  Layers would shrink deploys at the cost of another moving part.
- **Floci vs. LocalStack.** Free and fast, but newer (Feb 2026) with less
  community content and the OIDC gap. Wire-compatible with LocalStack, so
  migration is cheap if it ever becomes necessary.
- **One DynamoDB table.** Simplest possible storage, but the Scan in
  `list_items` is a known no-go past tiny datasets; the schema is fine for a
  read-mostly PoC and would be re-modeled (GSI or dedicated query table) with
  real growth.

## 5. What's next

Concrete, realistic follow-ups in rough priority order:

1. **Wire the prod deploy** — the `lambda-zerotrust-poc-github-actions-prod`
   role exists and is branch-locked to `main`; a prod apply job would override
   `AWS_ROLE_ARN` with an environment-scoped GitHub variable. This is the last
   piece of the two-environment story.
2. **CloudWatch alarms** — the dashboard proves the signal exists; the natural
   next step is `aws_cloudwatch_metric_alarm` on Lambda errors/throttles and
   API Gateway 4XX/5XX, plus the one `cloudwatch:PutMetricAlarm` statement the
   deploy role needs (`docs/observability.md` §5).
3. **Add a WAF** in front of API Gateway (rate limiting + AWS-managed rule set)
   — the single biggest security gap remaining.
4. **Hardening the pipeline** — pin *all* tool versions (Bandit, pip-audit,
   gitleaks are still unpinned in `security.yml`), add a `terraform fmt -check`
   gate, and consider OPA/Sentinel policy-as-code for the deploy step.
5. **Do a real cold-start measurement against AWS** — Floci's 2–5 s numbers
   are emulator artifacts; a real run would confirm whether provisioned
   concurrency is ever worth the money.

Every item above is scoped, documented, and traceable in this repo — the
decisions are in `decisions.md`, the numbers in `docs/cost.md`, and the
gap analysis in `docs/observability.md`.
