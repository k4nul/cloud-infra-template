#!/usr/bin/env sh
set -eu

export CHECKPOINT_DISABLE="${CHECKPOINT_DISABLE:-1}"
export TF_IN_AUTOMATION="${TF_IN_AUTOMATION:-1}"
export TF_INPUT="${TF_INPUT:-0}"

TERRAFORM_ENV_DIRS="${TERRAFORM_ENV_DIRS:-terraform/envs/dev terraform/envs/staging terraform/envs/prod}"
TERRAFORM_VALIDATE_MODE="${TERRAFORM_VALIDATE_MODE:-full}"
TERRAFORM_ENABLE_CHECKOV="${TERRAFORM_ENABLE_CHECKOV:-0}"
TERRAFORM_ENABLE_TFLINT="${TERRAFORM_ENABLE_TFLINT:-0}"
TERRAFORM_BIN="${TERRAFORM_BIN:-terraform}"
CHECKOV_BIN="${CHECKOV_BIN:-checkov}"
TFLINT_BIN="${TFLINT_BIN:-tflint}"

case "$TERRAFORM_VALIDATE_MODE" in
  full | static)
    ;;
  *)
    echo "Unsupported TERRAFORM_VALIDATE_MODE: $TERRAFORM_VALIDATE_MODE. Use full or static." >&2
    exit 1
    ;;
esac

ensure_command_available() {
  command_name=$1
  install_hint=$2

  case "$command_name" in
    */*)
      if [ -x "$command_name" ]; then
        return 0
      fi

      echo "$command_name not found or not executable. $install_hint" >&2
      return 127
      ;;
  esac

  if command -v "$command_name" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "${HOME:-}" ]; then
    for tool_dir in "$HOME/.local/bin" "$HOME/bin"; do
      if [ -x "$tool_dir/$command_name" ]; then
        case ":${PATH:-}:" in
          *":$tool_dir:"*) ;;
          *) PATH="$tool_dir${PATH:+:$PATH}"; export PATH ;;
        esac
        return 0
      fi
    done
  fi

  if [ -x "/usr/local/bin/$command_name" ]; then
    case ":${PATH:-}:" in
      *":/usr/local/bin:"*) ;;
      *) PATH="/usr/local/bin${PATH:+:$PATH}"; export PATH ;;
    esac
    return 0
  fi

  echo "$command_name not found. $install_hint" >&2
  return 127
}

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
        config/backend.hcl.example | *.tfvars.example | .env.example | */.env.example)
          ;;
        .terraform/* | */.terraform/* | .terraform.lock.hcl | */.terraform.lock.hcl | \
        .terraformrc | */.terraformrc | terraform.rc | */terraform.rc | \
          .terraform.d/* | */.terraform.d/* | .tflint.d/* | */.tflint.d/* | \
          *.tfvars | *.tfvars.json | *.tfstate | *.tfstate.* | *.tfplan | \
          *.tfplan.json | *.plan | *.plan.json | plan*.out | */plan*.out | \
          plan*.json | */plan*.json | \
          crash.log | */crash.log | crash.*.log | */crash.*.log | \
          .env | */.env | .env.* | */.env.* | .envrc | */.envrc | \
          *.pem | *.key | *.p12 | *.pfx | *.p8 | *.jks | *.keystore | \
          id_rsa | */id_rsa | id_dsa | */id_dsa | id_ecdsa | */id_ecdsa | \
          id_ed25519 | */id_ed25519 | config/*.hcl)
          printf '%s\n' "$tracked_file"
          ;;
      esac
    done
  )

  if [ -n "$violations" ]; then
    echo "Public-safety validation failed. Remove tracked generated, secret, state, plan, local credential, or real backend files:" >&2
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

    "$TERRAFORM_BIN" -chdir="$env_dir" init -backend=false -input=false -no-color
    "$TERRAFORM_BIN" -chdir="$env_dir" validate -no-color
  done
}

run_optional_policy_scan() {
  if [ "$TERRAFORM_ENABLE_CHECKOV" != "1" ]; then
    return 0
  fi

  ensure_command_available "$CHECKOV_BIN" \
    "Install Checkov, add it to PATH, or set CHECKOV_BIN before running with TERRAFORM_ENABLE_CHECKOV=1."

  "$CHECKOV_BIN" -d terraform --quiet
}

run_optional_tflint_scan() {
  if [ "$TERRAFORM_ENABLE_TFLINT" != "1" ]; then
    return 0
  fi

  ensure_command_available "$TFLINT_BIN" \
    "Install TFLint, run tflint --init if using plugins, add it to PATH, or set TFLINT_BIN before running with TERRAFORM_ENABLE_TFLINT=1."

  if [ -f ".tflint.hcl" ]; then
    "$TFLINT_BIN" --config="$(pwd)/.tflint.hcl" --recursive --chdir=terraform
    return 0
  fi

  "$TFLINT_BIN" --recursive --chdir=terraform
}

check_public_safe_files
ensure_command_available "$TERRAFORM_BIN" \
  "Install Terraform CLI >= 1.6.0, add it to PATH, or set TERRAFORM_BIN."
"$TERRAFORM_BIN" fmt -check -recursive terraform
if [ "$TERRAFORM_VALIDATE_MODE" != "static" ]; then
  validate_environment_roots
fi
run_optional_tflint_scan
run_optional_policy_scan
