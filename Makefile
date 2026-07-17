# ──────────────────────────────────────────────────────────
# Makefile — lambda-zerotrust-poc infrastructure lifecycle
# ──────────────────────────────────────────────────────────

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ── Config ───────────────────────────────────────────────
TF_DIR       := terraform
TF           := terraform -chdir=$(TF_DIR)
TFVARS       := -var-file=terraform.tfvars.example
FLOCI_PORT   := 4566
FLOCI_ENDPOINT := http://localhost:$(FLOCI_PORT)

# AWS env vars for Floci
export AWS_ENDPOINT_URL  := $(FLOCI_ENDPOINT)
export AWS_DEFAULT_REGION := us-east-1
export AWS_ACCESS_KEY_ID  := test
export AWS_SECRET_ACCESS_KEY := test

# ── Phony declarations ──────────────────────────────────
.PHONY: help \
        floci-up floci-down floci-restart floci-status floci-health floci-env \
        tf-init tf-plan tf-apply tf-destroy tf-validate tf-fmt \
        up down env build-lambdas \
        install-deps lint test clean

# ──────────────────────────────────────────────────────────
#  Help
# ──────────────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ──────────────────────────────────────────────────────────
#  Floci (local AWS emulator)
# ──────────────────────────────────────────────────────────
floci-up: ## Start Floci emulator
	docker compose up -d
	@echo "Waiting for Floci..."
	@timeout 30 bash -c 'until curl -sf $(FLOCI_ENDPOINT)/_localstack/health >/dev/null 2>&1; do sleep 1; done'
	@echo "Floci ready at $(FLOCI_ENDPOINT)"

floci-down: ## Stop and remove Floci container
	docker compose down

floci-restart: floci-down floci-up ## Restart Floci

floci-status: ## Show Floci container status
	@floci status 2>/dev/null || docker compose ps

floci-health: ## Check Floci health endpoint
	@curl -sf $(FLOCI_ENDPOINT)/_localstack/health | python3 -m json.tool

floci-env: ## Print AWS env vars for Floci
	@echo "export AWS_ENDPOINT_URL=$(FLOCI_ENDPOINT)"
	@echo "export AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION)"
	@echo "export AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID)"
	@echo "export AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)"

# ──────────────────────────────────────────────────────────
#  Terraform
# ──────────────────────────────────────────────────────────
tf-init: ## Initialize Terraform providers
	cd $(TF_DIR) && terraform init -reconfigure

tf-plan: ## Plan Terraform changes (Floci)
	$(TF) plan $(TFVARS)

tf-apply: ## Apply Terraform changes (Floci, auto-approve)
	$(TF) apply -auto-approve $(TFVARS)

tf-destroy: ## Destroy Terraform resources (Floci)
	$(TF) destroy -auto-approve $(TFVARS)

tf-validate: ## Validate Terraform configuration
	$(TF) validate

tf-fmt: ## Format Terraform files
	$(TF) fmt -recursive

# ──────────────────────────────────────────────────────────
#  Combined workflows
# ──────────────────────────────────────────────────────────
up: floci-up build-lambdas tf-init tf-apply ## Start Floci + build + deploy infra
	@echo "Infrastructure deployed to Floci"

down: tf-destroy floci-down ## Destroy infra + stop Floci
	@echo "Infrastructure destroyed, Floci stopped"

env: ## Export AWS env vars for Floci (eval $$(make env))
	@echo "export AWS_ENDPOINT_URL=$(FLOCI_ENDPOINT)"
	@echo "export AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION)"
	@echo "export AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID)"
	@echo "export AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)"

build-lambdas: ## Build Lambda deployment packages with dependencies
	@bash scripts/build-lambda.sh

# ──────────────────────────────────────────────────────────
#  Dev helpers
# ──────────────────────────────────────────────────────────
install-deps: ## Install Python dependencies
	pip install -e ".[dev]" 2>/dev/null || pip install pydantic aws-lambda-powertools pytest pytest-mock ruff bandit

lint: ## Run ruff linter
	ruff check src/ tests/

test: ## Run pytest
	pytest tests/ -v

clean: ## Remove Python/TF caches
	rm -rf .pytest_cache .coverage htmlcov __pycache__ .build
	rm -rf $(TF_DIR)/.terraform $(TF_DIR)/*.tfstate $(TF_DIR)/*.tfstate.backup
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
