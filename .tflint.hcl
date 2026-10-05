## TFLint configuration for expensr-infra
##
## TFLint catches Terraform mistakes that `terraform validate` does not:
## undocumented variables/outputs, unused declarations, inconsistent naming,
## and (via the AWS ruleset) provider-specific errors like invalid instance
## types. Run with: tflint --chdir=<env dir> --config=<path to this file>

config {
  # Follow `module` calls into local modules so the env configs lint the
  # modules they use. (Remote/registry modules are not fetched for linting.)
  call_module_type = "local"
}

## Built-in Terraform ruleset (ships bundled with TFLint, no download needed).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

## AWS ruleset — provider-aware checks (invalid instance types, bad AMIs,
## malformed IAM policies, deprecated arguments, etc.).
##
## This plugin is downloaded on `tflint --init`. It is left DISABLED for now
## because Phase 1 modules are empty stubs with no AWS resources to check.
## Enable it (and run `tflint --init`) once real resources land in Phase 3.
#
# plugin "aws" {
#   enabled = true
#   version = "0.45.0"
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }

## Rules we want on from day one, so Phase 3 code is held to them immediately.

# Every module must pin its Terraform and provider versions.
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# Variables and outputs must carry a description.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Consistent snake_case names for all Terraform identifiers.
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Flag declared-but-unused variables and data sources.
rule "terraform_unused_declarations" {
  enabled = true
}
