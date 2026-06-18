#!/usr/bin/env sh
set -eu

workflow_file="${CI_WORKFLOW_FILE:-.github/workflows/terraform-validate.yml}"

fail() {
  printf '%s\n' "CI workflow validation failed: $1" >&2
  exit 1
}

if [ ! -f "$workflow_file" ]; then
  fail "workflow file not found: $workflow_file"
fi

assert_line() {
  pattern=$1
  message=$2

  if ! grep -Eq "$pattern" "$workflow_file"; then
    fail "$message"
  fi
}

assert_absent() {
  pattern=$1
  message=$2

  if grep -Eq "$pattern" "$workflow_file"; then
    fail "$message"
  fi
}

extract_event_block() {
  event_name=$1

  awk -v event_name="$event_name" '
    $0 ~ "^[[:space:]]{2}" event_name ":[[:space:]]*$" {
      in_event = 1
      print
      next
    }
    in_event && $0 ~ "^[[:space:]]{2}[A-Za-z0-9_-]+:[[:space:]]*$" {
      exit
    }
    in_event {
      print
    }
  ' "$workflow_file"
}

extract_top_level_block() {
  block_name=$1

  awk -v block_name="$block_name" '
    $0 ~ "^" block_name ":[[:space:]]*$" {
      in_block = 1
      print
      next
    }
    in_block && $0 ~ "^[^[:space:]][^:]*:[[:space:]]*" {
      exit
    }
    in_block {
      print
    }
  ' "$workflow_file"
}

line_number() {
  pattern=$1

  awk -v pattern="$pattern" '$0 ~ pattern { print NR; exit }' "$workflow_file"
}

assert_order() {
  first_pattern=$1
  second_pattern=$2
  message=$3

  first_line=$(line_number "$first_pattern")
  second_line=$(line_number "$second_pattern")

  if [ -z "$first_line" ] || [ -z "$second_line" ]; then
    fail "$message"
  fi

  if [ "$first_line" -ge "$second_line" ]; then
    fail "$message"
  fi
}

assert_all_checkout_steps_disable_credentials() {
  awk '
    function finish_step() {
      if (checkout_seen && !persist_false_seen) {
        exit 1
      }
      checkout_seen = 0
      persist_false_seen = 0
    }

    /^[[:space:]]{6}-[[:space:]]/ {
      finish_step()
    }

    /^[[:space:]]+(-[[:space:]]+)?uses:[[:space:]]*actions\/checkout@/ {
      checkout_seen = 1
    }

    checkout_seen && /^[[:space:]]+persist-credentials:[[:space:]]*false[[:space:]]*$/ {
      persist_false_seen = 1
    }

    END {
      finish_step()
    }
  ' "$workflow_file" || fail "every checkout step must set persist-credentials: false"
}

assert_line '^name:[[:space:]]*Terraform validation[[:space:]]*$' \
  "workflow must be the Terraform validation workflow"
assert_line '^on:[[:space:]]*$' \
  "workflow must declare explicit triggers"
assert_absent '^[[:space:]]{2}pull_request_target:[[:space:]]*$' \
  "workflow must not use pull_request_target for untrusted template validation"
assert_line '^[[:space:]]{2}pull_request:[[:space:]]*$' \
  "workflow must run on pull_request"
assert_line '^[[:space:]]{2}push:[[:space:]]*$' \
  "workflow must run on pushes to main"
assert_line '^[[:space:]]{2}workflow_dispatch:[[:space:]]*$' \
  "workflow must support manual dispatch"
assert_line '^[[:space:]]{6}- main[[:space:]]*$' \
  "push trigger must include the main branch"

assert_absent '\$\{\{[[:space:]]*secrets([^A-Za-z0-9_]|$)' \
  "public validation workflow must not reference repository secrets"
assert_absent 'aws-actions/configure-aws-credentials|azure/login|google-github-actions/auth' \
  "public validation workflow must not configure cloud credentials"
assert_absent '^[[:space:]]+(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN|AWS_PROFILE|GOOGLE_APPLICATION_CREDENTIALS|GOOGLE_CREDENTIALS|AZURE_CLIENT_ID|AZURE_CLIENT_SECRET|AZURE_TENANT_ID|ARM_CLIENT_ID|ARM_CLIENT_SECRET|ARM_TENANT_ID|ARM_SUBSCRIPTION_ID):' \
  "public validation workflow must not set cloud credential environment variables"
assert_absent 'persist-credentials:[[:space:]]*true[[:space:]]*$' \
  "checkout credentials must not be persisted"
assert_absent '^[[:space:]]+permissions:[[:space:]]*' \
  "workflow must not override permissions below the top level"

pull_request_block=$(extract_event_block pull_request)
if printf '%s\n' "$pull_request_block" | grep -Eq '^[[:space:]]{4}(paths|paths-ignore):[[:space:]]*$'; then
  fail "pull_request path filters must not be configured"
fi

permissions_block=$(extract_top_level_block permissions)
if [ -z "$permissions_block" ]; then
  fail "workflow must declare read-only permissions"
fi
if ! printf '%s\n' "$permissions_block" | grep -Eq '^[[:space:]]{2}contents:[[:space:]]*read[[:space:]]*$'; then
  fail "workflow permissions must include contents: read"
fi
if printf '%s\n' "$permissions_block" | grep -Eq ':[[:space:]]*write[[:space:]]*$'; then
  fail "workflow permissions must not grant write access"
fi
if printf '%s\n' "$permissions_block" | grep -Eq '^[[:space:]]{2}id-token:'; then
  fail "workflow must not request id-token permissions"
fi

assert_line '^[[:space:]]{6}CHECKPOINT_DISABLE:[[:space:]]*"1"[[:space:]]*$' \
  "workflow must disable Terraform checkpoint calls"
assert_line '^[[:space:]]{6}TF_IN_AUTOMATION:[[:space:]]*"1"[[:space:]]*$' \
  "workflow must run Terraform in automation mode"
assert_line '^[[:space:]]{6}TF_INPUT:[[:space:]]*"0"[[:space:]]*$' \
  "workflow must disable Terraform input prompts"
assert_line '^[[:space:]]{6}TERRAFORM_ENABLE_CHECKOV:[[:space:]]*"0"[[:space:]]*$' \
  "public CI must keep Checkov optional"
assert_line '^[[:space:]]{6}TERRAFORM_ENABLE_TFLINT:[[:space:]]*"0"[[:space:]]*$' \
  "public CI must keep TFLint optional"

assert_line '^[[:space:]]{8}uses:[[:space:]]*actions/checkout@v4[[:space:]]*$' \
  "workflow must use actions/checkout@v4"
assert_line '^[[:space:]]{10}persist-credentials:[[:space:]]*false[[:space:]]*$' \
  "checkout must set persist-credentials: false"
assert_all_checkout_steps_disable_credentials
assert_line '^[[:space:]]{6}- name:[[:space:]]*Validate CI workflow contract[[:space:]]*$' \
  "workflow must validate its own CI contract"
assert_line '^[[:space:]]{8}run:[[:space:]]*\./scripts/validate-ci-workflow\.sh[[:space:]]*$' \
  "workflow contract step must run ./scripts/validate-ci-workflow.sh"
assert_line '^[[:space:]]{6}- name:[[:space:]]*Test validation contract[[:space:]]*$' \
  "workflow must run validation contract tests"
assert_line '^[[:space:]]{8}run:[[:space:]]*\./tests/validate_public_safety_test\.sh[[:space:]]*$' \
  "workflow must run ./tests/validate_public_safety_test.sh"
assert_line '^[[:space:]]{8}uses:[[:space:]]*hashicorp/setup-terraform@v3[[:space:]]*$' \
  "workflow must use hashicorp/setup-terraform@v3"
assert_line '^[[:space:]]{10}terraform_version:[[:space:]]*"1\.6\.6"[[:space:]]*$' \
  "workflow must pin Terraform 1.6.6"
assert_line '^[[:space:]]{6}- name:[[:space:]]*Run public-safe validation[[:space:]]*$' \
  "workflow must run public-safe validation"
assert_line '^[[:space:]]{8}run:[[:space:]]*\./scripts/validate\.sh[[:space:]]*$' \
  "workflow must run ./scripts/validate.sh"

assert_order '^[[:space:]]{6}- name:[[:space:]]*Validate CI workflow contract[[:space:]]*$' \
  '^[[:space:]]{6}- name:[[:space:]]*Test validation contract[[:space:]]*$' \
  "workflow contract validation must run before script contract tests"
assert_order '^[[:space:]]{6}- name:[[:space:]]*Test validation contract[[:space:]]*$' \
  '^[[:space:]]{8}uses:[[:space:]]*hashicorp/setup-terraform@v3[[:space:]]*$' \
  "script contract tests must run before Terraform setup"
assert_order '^[[:space:]]{8}uses:[[:space:]]*hashicorp/setup-terraform@v3[[:space:]]*$' \
  '^[[:space:]]{6}- name:[[:space:]]*Run public-safe validation[[:space:]]*$' \
  "Terraform setup must run before public-safe validation"

printf '%s\n' "ok - CI workflow contract"
