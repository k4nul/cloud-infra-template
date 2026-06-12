#!/usr/bin/env sh
set -eu

export CHECKPOINT_DISABLE="${CHECKPOINT_DISABLE:-1}"
export TF_IN_AUTOMATION="${TF_IN_AUTOMATION:-1}"
export TF_INPUT="${TF_INPUT:-0}"

TERRAFORM_ENV_DIRS="${TERRAFORM_ENV_DIRS:-terraform/envs/dev terraform/envs/staging terraform/envs/prod}"
TERRAFORM_ENABLE_CHECKOV="${TERRAFORM_ENABLE_CHECKOV:-0}"

check_public_safe_files() {
  if ! command -v git >/dev/null 2>&1; then
    echo "git not found; skipping tracked public-safety file check." >&2
    return 0
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi

  violations=$(
    git ls-files | while IFS= read -r tracked_file; do
      case "$tracked_file" in
        config/backend.hcl.example | *.tfvars.example)
          ;;
        .terraform/* | */.terraform/* | .terraform.lock.hcl | */.terraform.lock.hcl | \
          *.tfvars | *.tfvars.json | *.tfstate | *.tfstate.* | *.tfplan | *.plan | \
          plan*.out | */plan*.out | *.pem | *.key | *.p12 | config/*.hcl)
          printf '%s\n' "$tracked_file"
          ;;
      esac
    done
  )

  if [ -n "$violations" ]; then
    echo "Public-safety validation failed. Remove tracked generated, secret, state, plan, or real backend files:" >&2
    printf '%s\n' "$violations" | sed 's/^/  - /' >&2
    return 1
  fi
}

validate_environment_roots() {
  for env_dir in $TERRAFORM_ENV_DIRS; do
    if [ ! -d "$env_dir" ]; then
      echo "Terraform environment directory not found: $env_dir" >&2
      return 1
    fi

    terraform -chdir="$env_dir" init -backend=false -input=false -no-color
    terraform -chdir="$env_dir" validate -no-color
  done
}

run_optional_policy_scan() {
  if [ "$TERRAFORM_ENABLE_CHECKOV" != "1" ]; then
    return 0
  fi

  if ! command -v checkov >/dev/null 2>&1; then
    echo "TERRAFORM_ENABLE_CHECKOV=1 requested but checkov is not installed." >&2
    return 127
  fi

  checkov -d terraform --quiet
}

check_public_safe_files
terraform fmt -check -recursive terraform
validate_environment_roots
run_optional_policy_scan
