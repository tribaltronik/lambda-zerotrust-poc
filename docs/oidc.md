# GitHub Actions OIDC Trust Policy

This document explains how the repo deploys to AWS with **no long-lived AWS
credentials**, how the IAM role trust policies gate GitHub Actions by
repository, branch, and environment, and the exact `sub`/`aud` conditions in
`terraform/oidc.tf`.

## What GitHub OIDC does

GitHub OIDC federation lets GitHub Actions mint a short-lived, signed token
for a job instead of exchanging static AWS access keys:

1. The workflow requests an OIDC token with `permissions: id-token: write`
   (`actions/configure-aws-credentials` handles the request).
2. AWS STS validates the token's signature against the
   `token.actions.githubusercontent.com` OIDC provider.
3. STS calls `sts:AssumeRoleWithWebIdentity` with the token, which must satisfy
   the target IAM role's trust policy conditions (`aud`, `sub`, ...).
4. The job gets temporary credentials scoped to that role and its permissions
   policy, for the role's `max_session_duration` (here 3600s).

The credentials are short-lived, minted per job, and tied to the exact repo,
branch, and workflow that requested them — there are **no static secrets** in
GitHub and nothing to rotate or leak.

## Trust-policy conditions

Both deploy roles share the same `aud` condition and differ only in their `sub`
patterns. The conditions live in the `Condition` block of each role's
`assume_role_policy` (see `terraform/oidc.tf`, resource
`aws_iam_role.github_actions`):

- `token.actions.githubusercontent.com:aud = "sts.amazonaws.com"` — a
  **StringEquals** condition. The token's audience must be exactly
  `sts.amazonaws.com` (the client ID registered on the OIDC provider), so the
  token can only be redeemed at STS, never for another service.
- `token.actions.githubusercontent.com:sub` — a **StringLike** condition. The
  token subject encodes the repository and ref as
  `repo:<org>/<repo>:ref:<ref>`. Multiple patterns in one list value are OR'd
  by IAM, so a single Statement covers several ref classes.

### dev role — branch pushes + PRs

Pattern from `local.github_actions_sub_patterns["dev"]`:

```hcl
StringEquals = {
  "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
}
StringLike = {
  "token.actions.githubusercontent.com:sub" = [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*",
    "repo:${var.github_org}/${var.github_repo}:ref:refs/pull/*",
  ]
}
```

Rendered with `github_org`/`github_repo` set, this is
`repo:<org>/<repo>:ref:refs/heads/*` and `repo:<org>/<repo>:ref:refs/pull/*`.
The dev role is assumed by the PR `Terraform plan` job and the `Terraform
apply` job on `main` (both deploy to `dev`).

### prod role — `main` only

Pattern from `local.github_actions_sub_patterns["prod"]`:

```hcl
StringEquals = {
  "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
}
StringLike = {
  "token.actions.githubusercontent.com:sub" = [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
  ]
}
```

The prod role can only ever be assumed from a push to `main`. No PR, no other
branch, no other repo.

## Security intent

- **Another repo cannot assume either role.** The `sub` prefix is pinned to
  `repo:${var.github_org}/${var.github_repo}`, so a token minted by any other
  repository fails `StringLike`.
- **A PR cannot assume the prod role.** PR refs are `refs/pull/*`, which match
  the dev role but not prod's `refs/heads/main`.
- **A compromised non-`main` branch cannot deploy to prod.** Even with
  `id-token: write`, the trust policy rejects the token; a compromised branch
  is limited to `dev` scope (plan/apply on dev resources).
- **`aud` binds the token to STS.** The `sts.amazonaws.com` audience is the
  OIDC provider's `client_id_list`, so the token cannot be redeemed to mint
  credentials for anything other than the STS web-identity flow.

## Deploy roles

`terraform/oidc.tf` creates one role per environment (`for_each` over
`["dev", "prod"]`):

- `lambda-zerotrust-poc-github-actions-dev` — `refs/heads/*` + `refs/pull/*`
- `lambda-zerotrust-poc-github-actions-prod` — `refs/heads/main` only

Both attach an identical least-privilege inline policy named
`terraform-deploy` (`aws_iam_role_policy.github_actions_terraform`) scoped to
this stack's resources (`lambda-zerotrust-poc-*`) and its S3/DynamoDB
remote-state backend, so CI can run `terraform plan`/`apply` end-to-end.

### Variable wiring

- The repo-level GitHub variable `AWS_ROLE_ARN` points at the **dev** role
  ARN. It is consumed by `${{ vars.AWS_ROLE_ARN }}` in
  `.github/workflows/terraform-plan.yml` (PR) and
  `.github/workflows/terraform-apply.yml` (`environment: dev`).
- The apply workflow runs with `environment: dev` (manual-approval gate), so
  dev is the only environment currently deployed.
- A future prod job would override `AWS_ROLE_ARN` with an **environment-scoped
  GitHub variable** on environment `prod`, pointing at the
  `lambda-zerotrust-poc-github-actions-prod` role ARN. GitHub variables resolve
  with environment scope taking precedence over repo scope, so the prod job
  picks up the prod role without changing the shared workflow code.

## Floci caveat

`use_localstack=true` (the local default) **skips** OIDC provider creation —
`aws_iam_openid_connect_provider.github` has `count = var.use_localstack ? 0 : 1`,
and each role's trust policy degrades to trusting the emulator account root via
`sts:AssumeRole`. The `aud`/`sub` conditions and the OIDC federation flow are
therefore only exercisable against **real AWS** (`use_localstack=false`), as
Floci does not emulate OIDC provider creation.
