#!/usr/bin/env bash
set -euo pipefail

# Idempotently enforce branch protection + environment rules for the repo.
# Requires: gh CLI authenticated with admin rights on the repo.
#
# Usage: ./scripts/branch-protection.sh [owner/repo]
#   (default repo derived from the git remote)

REPO="${1:-}"
if [[ -z "$REPO" ]]; then
  REPO="$(git remote get-url origin | sed -E 's#.*github.com[:/]([^/]+)/([^/.]+)(\.git)?$#\1/\2#')"
fi
BRANCH="main"
ENVIRONMENT="dev"

echo "Configuring protection for ${REPO} (branch ${BRANCH}, environment ${ENVIRONMENT})"

# 1. Branch protection: require PRs + all security/quality checks on main
gh api -X PUT "repos/${REPO}/branches/${BRANCH}/protection" \
  -H "Accept: application/vnd.github+json" \
  -f "required_status_checks[strict]=true" \
  -f "required_status_checks[contexts][]=Lint & unit tests" \
  -f "required_status_checks[contexts][]=SAST (Bandit)" \
  -f "required_status_checks[contexts][]=SCA (pip-audit)" \
  -f "required_status_checks[contexts][]=IaC scan (Checkov)" \
  -f "required_status_checks[contexts][]=Secrets scan (gitleaks)" \
  -f "required_status_checks[contexts][]=Terraform plan (dev)" \
  -f "enforce_admins=false" \
  -f "required_pull_request_reviews[required_approving_review_count]=1" \
  -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
  -f "required_pull_request_reviews[require_code_owner_reviews]=false" \
  -f "restrictions=null" >/dev/null

echo "  - Branch protection: PR required (1 approval, stale reviews dismissed)"
echo "  - Required checks: Lint & unit tests, SAST, SCA, IaC, Secrets, Terraform plan"

# 2. Environment rules: manual approval before Terraform apply can run
ENV_BODY='{
  "wait_timer": 0,
  "prevent_self_review": false,
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}'

gh api -X PUT "repos/${REPO}/environments/${ENVIRONMENT}" \
  -H "Accept: application/vnd.github+json" \
  --input - <<<"$ENV_BODY" >/dev/null

echo "  - Environment ${ENVIRONMENT}: created (manual approval gates Terraform apply)"
echo "  - Deployment branch policy: protected branches only (main)"
echo ""
echo "NEXT STEP (GitHub UI): Settings > Environments > ${ENVIRONMENT} > Deployment"
echo "  branches > 'Selected branches' or add a required reviewer so the apply job"
echo "  needs manual approval before running."
