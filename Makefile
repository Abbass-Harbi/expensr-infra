# expensr-infra Makefile
# =============================================================================
# Every Terraform command runs through here, never typed by hand. The contract:
#
#     `make check` runs EXACTLY what the PR pipeline runs.
#     Green local `make check`  ==>  green PR.
#
# If the two ever diverge, this Makefile is wrong. Run `make help` for targets.
# =============================================================================

# Use a POSIX shell for recipes. This matches CI (ubuntu) and Git Bash on
# Windows, and is required by the destroy guard's `read`/`test` logic.
# Override on Windows if sh is not at /bin/sh, e.g.
#   make check SHELL="C:/Program Files/Git/usr/bin/sh.exe"
SHELL ?= /bin/sh

# ---- Tool references ---------------------------------------------------------
# Referenced by short name so this file is correct on CI and on teammates'
# machines. Override on the command line if a tool lives elsewhere, e.g.
#   make lint TFLINT=/custom/path/tflint
TERRAFORM ?= terraform
TFLINT    ?= tflint
CHECKOV   ?= checkov
TRIVY     ?= trivy

# ---- Environment layout ------------------------------------------------------
# One environment only for this project (Task 1: staging; no dev/prod).
ENV      ?= staging
ENV_DIR  := envs/$(ENV)
TFVARS   := terraform.tfvars

# Run terraform inside the environment directory without cd-ing by hand.
TF := $(TERRAFORM) -chdir=$(ENV_DIR)

# Absolute path to the tflint config at the repo root (tflint is run with the
# env dir as its working directory, so it needs an explicit config path).
TFLINT_CONFIG := $(CURDIR)/.tflint.hcl

# ---- Values used by the destroy guard ---------------------------------------
# name_prefix: read from the env's tfvars; falls back to the project default.
NAME_PREFIX := $(shell sed -n 's/^[[:space:]]*name_prefix[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' $(ENV_DIR)/$(TFVARS) 2>/dev/null)
ifeq ($(strip $(NAME_PREFIX)),)
NAME_PREFIX := expensr
endif

# State bucket/key: parsed from a backend "s3" block if one exists. The remote
# backend is set up in Task 2; until then state is local and these read as
# "(local state - not configured yet)".
STATE_BUCKET := $(shell sed -n 's/^[[:space:]]*bucket[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' $(ENV_DIR)/backend.tf 2>/dev/null)
STATE_KEY    := $(shell sed -n 's/^[[:space:]]*key[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' $(ENV_DIR)/backend.tf 2>/dev/null)
ifeq ($(strip $(STATE_BUCKET)),)
STATE_BUCKET := (local state - not configured yet)
endif
ifeq ($(strip $(STATE_KEY)),)
STATE_KEY := (local state - not configured yet)
endif

.DEFAULT_GOAL := help

# ---- Terraform lifecycle -----------------------------------------------------

.PHONY: init
init: ## terraform init
	$(TF) init

.PHONY: fmt
fmt: ## terraform fmt -recursive (rewrites files in place)
	$(TERRAFORM) fmt -recursive

.PHONY: validate
validate: ## fmt -check + terraform validate (no changes made)
	$(TERRAFORM) fmt -recursive -check
	$(TF) validate

.PHONY: lint
lint: ## tflint
	$(TFLINT) --chdir=$(ENV_DIR) --config=$(TFLINT_CONFIG)

.PHONY: security
security: ## checkov + trivy config
	$(CHECKOV) --config-file .checkov.yaml
	$(TRIVY) config .

# The contract with CI: this is exactly what the PR pipeline runs.
.PHONY: check
check: validate lint security ## validate + lint + security  (what CI runs)

.PHONY: plan
plan: ## terraform plan
	$(TF) plan -var-file=$(TFVARS)

.PHONY: apply
apply: ## terraform apply
	$(TF) apply -var-file=$(TFVARS)

.PHONY: output
output: ## terraform output
	$(TF) output

# ---- Guarded destroy ---------------------------------------------------------
# This AWS account is shared with three parallel deployments, so a destroy
# pointed at the wrong state is the worst failure available. Before doing
# anything we print the target and require the operator to type the name_prefix.
# This NEVER touches the state bucket itself (that lives outside Terraform and
# is managed in Task 2).

.PHONY: destroy
destroy: ## terraform destroy (prints target, requires typed confirmation)
	@echo "============================================================"
	@echo " DESTROY GUARD - review carefully before confirming"
	@echo "------------------------------------------------------------"
	@echo " environment : $(ENV)"
	@echo " name_prefix : $(NAME_PREFIX)"
	@echo " state bucket: $(STATE_BUCKET)"
	@echo " state key   : $(STATE_KEY)"
	@echo "------------------------------------------------------------"
	@echo " Destroys the Terraform-managed resources above."
	@echo " Does NOT touch the state bucket."
	@echo "============================================================"
	@printf 'Type the name_prefix (%s) to confirm: ' "$(NAME_PREFIX)"; \
	read confirm; \
	if [ "$$confirm" != "$(NAME_PREFIX)" ]; then \
		echo "Confirmation did not match. Aborting."; \
		exit 1; \
	fi; \
	echo "Confirmed. Proceeding with destroy."
	$(TF) destroy -var-file=$(TFVARS)

# ---- Help --------------------------------------------------------------------

.PHONY: help
help: ## Show this help (list of targets)
	@echo "expensr-infra - make targets (ENV=$(ENV)):"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-9s\033[0m %s\n", $$1, $$2}'
