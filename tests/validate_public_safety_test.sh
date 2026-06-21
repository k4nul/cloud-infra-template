#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/cloud-infra-template-test.XXXXXX")

cleanup() {
  if [ -n "$test_tmp" ] && [ -d "$test_tmp" ]; then
    rm -rf "$test_tmp"
  fi
}

trap cleanup EXIT INT TERM

fail() {
  printf '%s\n' "not ok - $1" >&2
  exit 1
}

read_file_or_empty() {
  file_path=$1

  if [ -f "$file_path" ]; then
    cat "$file_path"
  fi
}

assert_contains() {
  haystack=$1
  needle=$2

  case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain: $needle" ;;
  esac
}

assert_not_contains() {
  haystack=$1
  needle=$2

  case "$haystack" in
    *"$needle"*) fail "expected output not to contain: $needle" ;;
    *) ;;
  esac
}

assert_git_ignores_path() {
  ignored_path=$1

  (
    cd "$repo_root"
    git check-ignore -q -- "$ignored_path"
  ) || fail "expected .gitignore to ignore: $ignored_path"
}

assert_git_allows_path() {
  allowed_path=$1

  set +e
  (
    cd "$repo_root"
    git check-ignore -q -- "$allowed_path"
  )
  status=$?
  set -e

  case "$status" in
    0) fail "expected .gitignore to allow: $allowed_path" ;;
    1) ;;
    *) fail "git check-ignore failed for allowed path: $allowed_path" ;;
  esac
}

make_terraform_stub() {
  mkdir -p "$test_tmp/bin"
  cat >"$test_tmp/bin/terraform" <<'STUB'
#!/usr/bin/env sh
set -eu

if [ -n "${TERRAFORM_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$TERRAFORM_STUB_LOG"
fi

case "${1:-}" in
  -chdir=*)
    shift
    ;;
esac

case "${1:-}" in
  fmt | init | validate)
    exit 0
    ;;
  *)
    printf '%s\n' "unexpected terraform command: $*" >&2
    exit 2
    ;;
esac
STUB
  chmod +x "$test_tmp/bin/terraform"
}

make_checkov_stub() {
  mkdir -p "$test_tmp/bin"
  cat >"$test_tmp/bin/checkov" <<'STUB'
#!/usr/bin/env sh
set -eu

if [ -n "${CHECKOV_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$CHECKOV_STUB_LOG"
fi

exit 0
STUB
  chmod +x "$test_tmp/bin/checkov"
}

make_tflint_stub() {
  mkdir -p "$test_tmp/bin"
  cat >"$test_tmp/bin/tflint" <<'STUB'
#!/usr/bin/env sh
set -eu

if [ -n "${TFLINT_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$TFLINT_STUB_LOG"
fi

exit 0
STUB
  chmod +x "$test_tmp/bin/tflint"
}

make_home_terraform_stub() {
  home_dir=$1

  mkdir -p "$home_dir/.local/bin"
  cat >"$home_dir/.local/bin/terraform" <<'STUB'
#!/usr/bin/env sh
set -eu

if [ -n "${TERRAFORM_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$TERRAFORM_STUB_LOG"
fi

case "${1:-}" in
  -chdir=*)
    shift
    ;;
esac

case "${1:-}" in
  fmt | init | validate)
    exit 0
    ;;
  *)
    printf '%s\n' "unexpected terraform command: $*" >&2
    exit 2
    ;;
esac
STUB
  chmod +x "$home_dir/.local/bin/terraform"
}

make_home_checkov_stub() {
  home_dir=$1

  mkdir -p "$home_dir/bin"
  cat >"$home_dir/bin/checkov" <<'STUB'
#!/usr/bin/env sh
set -eu

if [ -n "${CHECKOV_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$CHECKOV_STUB_LOG"
fi

exit 0
STUB
  chmod +x "$home_dir/bin/checkov"
}

make_home_tflint_stub() {
  home_dir=$1

  mkdir -p "$home_dir/bin"
  cat >"$home_dir/bin/tflint" <<'STUB'
#!/usr/bin/env sh
set -eu

if [ -n "${TFLINT_STUB_LOG:-}" ]; then
  printf '%s\n' "$*" >>"$TFLINT_STUB_LOG"
fi

exit 0
STUB
  chmod +x "$home_dir/bin/tflint"
}

make_target_repo() {
  target=$1

  mkdir -p "$target/terraform/envs/dev" \
    "$target/terraform/envs/staging" \
    "$target/terraform/envs/prod" \
    "$target/config"
  (
    cd "$target"
    git init -q
    git config user.email test@example.com
    git config user.name "Test User"
  )
}

run_validation() {
  target=$1
  terraform_log=${2:-}

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" TERRAFORM_STUB_LOG="$terraform_log" "$repo_root/scripts/validate.sh"
  )
}

run_ci_workflow_validation() {
  workflow_file=$1

  CI_WORKFLOW_FILE="$workflow_file" "$repo_root/scripts/validate-ci-workflow.sh"
}

test_ci_workflow_contract_accepts_repository_workflow() {
  output=$(run_ci_workflow_validation "$repo_root/.github/workflows/terraform-validate.yml" 2>&1) || {
    fail "expected repository CI workflow contract to pass, got: $output"
  }

  assert_contains "$output" "ok - CI workflow contract"
}

test_ci_workflow_contract_rejects_pull_request_path_filters() {
  workflow_file="$test_tmp/terraform-validate-path-filter.yml"

  awk '
    /^  pull_request:[[:space:]]*$/ {
      print
      print "    paths:"
      print "      - terraform/**"
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected pull_request path filters to fail CI workflow validation"
  assert_contains "$output" "pull_request path filters must not be configured"
}

test_ci_workflow_contract_rejects_pull_request_target() {
  workflow_file="$test_tmp/terraform-validate-pr-target.yml"

  sed 's/^  pull_request:/  pull_request_target:/' \
    "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected pull_request_target to fail CI workflow validation"
  assert_contains "$output" "pull_request_target"
}

test_ci_workflow_contract_rejects_secret_usage() {
  workflow_file="$test_tmp/terraform-validate-secrets.yml"

  awk '
    /^          persist-credentials: false[[:space:]]*$/ {
      print
      print ""
      print "      - name: Configure credentials"
      print "        env:"
      print "          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}"
      print "        run: true"
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected repository secret usage to fail CI workflow validation"
  assert_contains "$output" "must not reference repository secrets"
}

test_ci_workflow_contract_rejects_bracket_secret_usage() {
  workflow_file="$test_tmp/terraform-validate-bracket-secrets.yml"

  awk '
    /^          persist-credentials: false[[:space:]]*$/ {
      print
      print ""
      print "      - name: Read token"
      print "        env:"
      print "          TEMPLATE_TOKEN: ${{ secrets[\"TEMPLATE_TOKEN\"] }}"
      print "        run: true"
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected bracket secret usage to fail CI workflow validation"
  assert_contains "$output" "must not reference repository secrets"
}

test_ci_workflow_contract_rejects_write_permissions() {
  workflow_file="$test_tmp/terraform-validate-write-permissions.yml"

  awk '
    /^  contents: read[[:space:]]*$/ {
      print
      print "  actions: write"
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected write permissions to fail CI workflow validation"
  assert_contains "$output" "workflow permissions must not grant write access"
}

test_ci_workflow_contract_rejects_id_token_permissions() {
  workflow_file="$test_tmp/terraform-validate-id-token.yml"

  awk '
    /^permissions:[[:space:]]*$/ {
      print
      print "  id-token: read"
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected id-token permissions to fail CI workflow validation"
  assert_contains "$output" "workflow must not request id-token permissions"
}

test_ci_workflow_contract_rejects_job_permission_override() {
  workflow_file="$test_tmp/terraform-validate-job-permissions.yml"

  awk '
    /^  validate:[[:space:]]*$/ {
      print
      print "    permissions:"
      print "      contents: write"
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected job-level permissions to fail CI workflow validation"
  assert_contains "$output" "workflow must not override permissions below the top level"
}

test_ci_workflow_contract_rejects_persisted_checkout_credentials() {
  workflow_file="$test_tmp/terraform-validate-persisted-checkout.yml"

  sed 's/^          persist-credentials: false/          persist-credentials: true/' \
    "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected persisted checkout credentials to fail CI workflow validation"
  assert_contains "$output" "checkout credentials must not be persisted"
}

test_ci_workflow_contract_rejects_checkout_missing_persist_false() {
  workflow_file="$test_tmp/terraform-validate-extra-checkout.yml"

  awk '
    /^      - name: Validate CI workflow contract[[:space:]]*$/ {
      print "      - uses: actions/checkout@v4"
      print ""
      print
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected checkout without persist-credentials false to fail CI workflow validation"
  assert_contains "$output" "every checkout step must set persist-credentials: false"
}

test_ci_workflow_contract_rejects_cloud_credential_action() {
  workflow_file="$test_tmp/terraform-validate-cloud-credentials.yml"

  awk '
    /^      - name: Validate CI workflow contract[[:space:]]*$/ {
      print "      - name: Configure cloud credentials"
      print "        uses: aws-actions/configure-aws-credentials@v4"
      print
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected cloud credential action to fail CI workflow validation"
  assert_contains "$output" "public validation workflow must not configure cloud credentials"
}

test_ci_workflow_contract_rejects_cloud_credential_env() {
  workflow_file="$test_tmp/terraform-validate-cloud-env.yml"

  awk '
    /^      - name: Validate CI workflow contract[[:space:]]*$/ {
      print "      - name: Set cloud credentials"
      print "        env:"
      print "          AWS_ACCESS_KEY_ID: example"
      print "        run: true"
      print ""
      print
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected cloud credential environment variable to fail CI workflow validation"
  assert_contains "$output" "public validation workflow must not set cloud credential environment variables"
}

test_ci_workflow_contract_rejects_inline_cloud_credential_env() {
  workflow_file="$test_tmp/terraform-validate-inline-cloud-env.yml"

  awk '
    /^      - name: Validate CI workflow contract[[:space:]]*$/ {
      print "      - name: Set inline cloud credentials"
      print "        env: { AWS_SHARED_CREDENTIALS_FILE: /tmp/credentials }"
      print "        run: true"
      print ""
      print
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected inline cloud credential environment variable to fail CI workflow validation"
  assert_contains "$output" "public validation workflow must not set cloud credential environment variables"
}

test_ci_workflow_contract_rejects_quoted_inline_cloud_credential_env() {
  workflow_file="$test_tmp/terraform-validate-quoted-inline-cloud-env.yml"

  awk '
    /^      - name: Validate CI workflow contract[[:space:]]*$/ {
      print "      - name: Set quoted inline cloud credentials"
      print "        env: { \"AWS_ACCESS_KEY_ID\": example }"
      print "        run: true"
      print ""
      print
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected quoted inline cloud credential environment variable to fail CI workflow validation"
  assert_contains "$output" "public validation workflow must not set cloud credential environment variables"
}

test_ci_workflow_contract_rejects_single_quoted_inline_cloud_credential_env() {
  workflow_file="$test_tmp/terraform-validate-single-quoted-inline-cloud-env.yml"

  awk '
    /^      - name: Validate CI workflow contract[[:space:]]*$/ {
      print "      - name: Set single-quoted inline cloud credentials"
      print "        env: { \047AWS_SECRET_ACCESS_KEY\047: example }"
      print "        run: true"
      print ""
      print
      next
    }
    { print }
  ' "$repo_root/.github/workflows/terraform-validate.yml" >"$workflow_file"

  set +e
  output=$(run_ci_workflow_validation "$workflow_file" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected single-quoted inline cloud credential environment variable to fail CI workflow validation"
  assert_contains "$output" "public validation workflow must not set cloud credential environment variables"
}

test_gitignore_blocks_public_safety_artifacts() {
  for ignored_path in \
    ".terraform.lock.hcl" \
    ".terraformrc" \
    "terraform.rc" \
    ".terraform.d/credentials.tfrc.json" \
    ".tflint.d/plugins/cache.txt" \
    ".aws/credentials" \
    ".azure/azureProfile.json" \
    ".config/gcloud/application_default_credentials.json" \
    "terraform/envs/dev/.terraform/providers/cache.txt" \
    "terraform/envs/dev/terraform.tfvars" \
    "terraform/envs/dev/terraform.tfvars.json" \
    "terraform/envs/dev/dev.auto.tfvars" \
    "terraform/envs/dev/dev.auto.tfvars.json" \
    "terraform.tfstate" \
    "terraform.tfstate.backup" \
    "app.tfplan" \
    "app.tfplan.json" \
    "app.plan" \
    "app.plan.json" \
    "plan-dev.out" \
    "plan-dev.json" \
    "crash.log" \
    "crash.123.log" \
    ".env" \
    ".env.local" \
    ".envrc" \
    "secret.pem" \
    "secret.key" \
    "secret.p12" \
    "secret.pfx" \
    "secret.p8" \
    "secret.jks" \
    "secret.keystore" \
    "id_rsa" \
    "id_dsa" \
    "id_ecdsa" \
    "id_ed25519" \
    "config/prod.hcl"
  do
    assert_git_ignores_path "$ignored_path"
  done
}

test_gitignore_blocks_nested_public_safety_artifacts() {
  for ignored_path in \
    "nested/.terraform/providers/cache.txt" \
    "nested/.terraform.lock.hcl" \
    "nested/.terraformrc" \
    "nested/terraform.rc" \
    "nested/.terraform.d/credentials.tfrc.json" \
    "nested/.tflint.d/plugins/cache.txt" \
    "nested/.aws/credentials" \
    "nested/.azure/azureProfile.json" \
    "nested/.env.local" \
    "nested/.envrc" \
    "nested/secret.pem" \
    "nested/id_rsa" \
    "nested/id_ed25519" \
    "nested/plan-prod.out" \
    "services/api/.aws/credentials" \
    "services/api/.azure/azureProfile.json" \
    "services/api/.envrc"
  do
    assert_git_ignores_path "$ignored_path"
  done
}

test_gitignore_allows_public_examples() {
  for allowed_path in \
    "config/backend.hcl.example" \
    "terraform/envs/dev/terraform.tfvars.example" \
    ".env.example" \
    "services/api/.env.example"
  do
    assert_git_allows_path "$allowed_path"
  done
}

test_allows_public_examples() {
  target="$test_tmp/allows-public-examples"
  make_target_repo "$target"

  mkdir -p "$target/terraform/envs/dev" "$target/services/api"
  touch "$target/config/backend.hcl.example"
  touch "$target/terraform/envs/dev/terraform.tfvars.example"
  touch "$target/.env.example"
  touch "$target/services/api/.env.example"

  (
    cd "$target"
    git add .env.example \
      config/backend.hcl.example \
      services/api/.env.example \
      terraform/envs/dev/terraform.tfvars.example
  )

  run_validation "$target" >"$test_tmp/validate-public-examples.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-public-examples.out")
    fail "expected public examples to pass, got: $output"
  }
}

test_ignores_untracked_forbidden_files() {
  target="$test_tmp/ignores-untracked"
  make_target_repo "$target"

  touch "$target/terraform/envs/dev/terraform.tfvars"
  touch "$target/.terraform.lock.hcl"
  touch "$target/config/prod.hcl"
  touch "$target/.env"
  mkdir -p "$target/.aws" "$target/.azure" "$target/.config/gcloud"
  touch "$target/.aws/credentials"
  touch "$target/.azure/azureProfile.json"
  touch "$target/.config/gcloud/application_default_credentials.json"
  touch "$target/.terraformrc"
  touch "$target/crash.log"
  touch "$target/id_ed25519"

  run_validation "$target" >"$test_tmp/validate-untracked.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-untracked.out")
    fail "expected untracked forbidden files to pass, got: $output"
  }
}

test_rejects_tracked_forbidden_files() {
  target="$test_tmp/rejects-forbidden"
  make_target_repo "$target"

  mkdir -p "$target/terraform/envs/dev/.terraform/providers" \
    "$target/.terraform.d" \
    "$target/.tflint.d/plugins" \
    "$target/.aws" \
    "$target/.azure" \
    "$target/.config/gcloud" \
    "$target/nested" \
    "$target/nested/.terraform" \
    "$target/nested/.terraform.d" \
    "$target/nested/.tflint.d/plugins" \
    "$target/nested/.config/gcloud" \
    "$target/services/api/.aws" \
    "$target/services/api/.azure" \
    "$target/services/api/.config/gcloud"
  touch "$target/.env"
  touch "$target/.env.local"
  touch "$target/.envrc"
  touch "$target/.terraformrc"
  touch "$target/terraform.rc"
  touch "$target/.terraform.d/credentials.tfrc.json"
  touch "$target/.tflint.d/plugins/cache.txt"
  touch "$target/.aws/credentials"
  touch "$target/.aws/config"
  touch "$target/.azure/azureProfile.json"
  touch "$target/.config/gcloud/application_default_credentials.json"
  touch "$target/.terraform.lock.hcl"
  touch "$target/terraform/envs/dev/.terraform/providers/cache.txt"
  touch "$target/terraform/envs/dev/terraform.tfvars"
  touch "$target/terraform/envs/dev/terraform.tfvars.json"
  touch "$target/terraform/envs/dev/dev.auto.tfvars"
  touch "$target/terraform/envs/dev/dev.auto.tfvars.json"
  touch "$target/terraform.tfstate"
  touch "$target/terraform.tfstate.backup"
  touch "$target/app.tfplan"
  touch "$target/app.tfplan.json"
  touch "$target/app.plan"
  touch "$target/app.plan.json"
  touch "$target/plan-dev.out"
  touch "$target/plan-dev.json"
  touch "$target/nested/plan-prod.out"
  touch "$target/nested/.terraform/providers-cache.txt"
  touch "$target/nested/.terraform.lock.hcl"
  touch "$target/nested/.terraformrc"
  touch "$target/nested/terraform.rc"
  touch "$target/nested/.terraform.d/credentials.tfrc.json"
  touch "$target/nested/.tflint.d/plugins/cache.txt"
  touch "$target/nested/.config/gcloud/application_default_credentials.json"
  touch "$target/nested/.envrc"
  touch "$target/nested/secret.pem"
  touch "$target/crash.log"
  touch "$target/crash.123.log"
  touch "$target/secret.pem"
  touch "$target/secret.key"
  touch "$target/secret.p12"
  touch "$target/secret.pfx"
  touch "$target/secret.p8"
  touch "$target/secret.jks"
  touch "$target/secret.keystore"
  touch "$target/id_rsa"
  touch "$target/id_dsa"
  touch "$target/id_ecdsa"
  touch "$target/id_ed25519"
  touch "$target/config/prod.hcl"
  touch "$target/nested/.env.local"
  touch "$target/nested/id_rsa"
  touch "$target/services/api/.aws/credentials"
  touch "$target/services/api/.azure/azureProfile.json"
  touch "$target/services/api/.config/gcloud/application_default_credentials.json"

  (
    cd "$target"
    git add .
  )

  set +e
  output=$(run_validation "$target" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected tracked forbidden files to fail validation"

  assert_contains "$output" "Public-safety validation failed."
  assert_contains "$output" ".env"
  assert_contains "$output" ".env.local"
  assert_contains "$output" ".envrc"
  assert_contains "$output" ".terraformrc"
  assert_contains "$output" "terraform.rc"
  assert_contains "$output" ".terraform.d/credentials.tfrc.json"
  assert_contains "$output" ".tflint.d/plugins/cache.txt"
  assert_contains "$output" ".aws/credentials"
  assert_contains "$output" ".aws/config"
  assert_contains "$output" ".azure/azureProfile.json"
  assert_contains "$output" ".config/gcloud/application_default_credentials.json"
  assert_contains "$output" ".terraform.lock.hcl"
  assert_contains "$output" "terraform/envs/dev/.terraform/providers/cache.txt"
  assert_contains "$output" "terraform/envs/dev/terraform.tfvars"
  assert_contains "$output" "terraform/envs/dev/terraform.tfvars.json"
  assert_contains "$output" "terraform/envs/dev/dev.auto.tfvars"
  assert_contains "$output" "terraform/envs/dev/dev.auto.tfvars.json"
  assert_contains "$output" "terraform.tfstate"
  assert_contains "$output" "terraform.tfstate.backup"
  assert_contains "$output" "app.tfplan"
  assert_contains "$output" "app.tfplan.json"
  assert_contains "$output" "app.plan"
  assert_contains "$output" "app.plan.json"
  assert_contains "$output" "plan-dev.out"
  assert_contains "$output" "plan-dev.json"
  assert_contains "$output" "nested/plan-prod.out"
  assert_contains "$output" "nested/.terraform/providers-cache.txt"
  assert_contains "$output" "nested/.terraform.lock.hcl"
  assert_contains "$output" "nested/.terraformrc"
  assert_contains "$output" "nested/terraform.rc"
  assert_contains "$output" "nested/.terraform.d/credentials.tfrc.json"
  assert_contains "$output" "nested/.tflint.d/plugins/cache.txt"
  assert_contains "$output" "nested/.config/gcloud/application_default_credentials.json"
  assert_contains "$output" "nested/.envrc"
  assert_contains "$output" "nested/secret.pem"
  assert_contains "$output" "crash.log"
  assert_contains "$output" "crash.123.log"
  assert_contains "$output" "secret.pem"
  assert_contains "$output" "secret.key"
  assert_contains "$output" "secret.p12"
  assert_contains "$output" "secret.pfx"
  assert_contains "$output" "secret.p8"
  assert_contains "$output" "secret.jks"
  assert_contains "$output" "secret.keystore"
  assert_contains "$output" "id_rsa"
  assert_contains "$output" "id_dsa"
  assert_contains "$output" "id_ecdsa"
  assert_contains "$output" "id_ed25519"
  assert_contains "$output" "config/prod.hcl"
  assert_contains "$output" "nested/.env.local"
  assert_contains "$output" "nested/id_rsa"
  assert_contains "$output" "services/api/.aws/credentials"
  assert_contains "$output" "services/api/.azure/azureProfile.json"
  assert_contains "$output" "services/api/.config/gcloud/application_default_credentials.json"
}

test_rejects_only_forbidden_files_when_public_examples_are_tracked() {
  target="$test_tmp/rejects-only-forbidden-with-examples"
  make_target_repo "$target"

  mkdir -p "$target/terraform/envs/dev" "$target/services/api"
  touch "$target/config/backend.hcl.example"
  touch "$target/config/prod.hcl"
  touch "$target/terraform/envs/dev/terraform.tfvars.example"
  touch "$target/terraform/envs/dev/terraform.tfvars"
  touch "$target/.env.example"
  touch "$target/.env"
  touch "$target/services/api/.env.example"

  (
    cd "$target"
    git add .
  )

  set +e
  output=$(run_validation "$target" 2>&1)
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail "expected tracked forbidden files to fail validation"

  assert_contains "$output" "Public-safety validation failed."
  assert_contains "$output" "config/prod.hcl"
  assert_contains "$output" "terraform/envs/dev/terraform.tfvars"
  assert_contains "$output" ".env"
  assert_not_contains "$output" "config/backend.hcl.example"
  assert_not_contains "$output" "terraform/envs/dev/terraform.tfvars.example"
  assert_not_contains "$output" ".env.example"
  assert_not_contains "$output" "services/api/.env.example"
}

test_default_matrix_runs_all_environment_roots() {
  target="$test_tmp/default-matrix"
  make_target_repo "$target"
  terraform_log="$test_tmp/default-matrix-terraform.log"

  run_validation "$target" "$terraform_log" >"$test_tmp/validate-default-matrix.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-default-matrix.out")
    fail "expected default matrix to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")

  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/dev init -backend=false -input=false -no-color"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/dev validate -no-color"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/staging init -backend=false -input=false -no-color"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/staging validate -no-color"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/prod init -backend=false -input=false -no-color"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/prod validate -no-color"
}

test_custom_matrix_limits_environment_roots() {
  target="$test_tmp/custom-matrix"
  make_target_repo "$target"
  terraform_log="$test_tmp/custom-matrix-terraform.log"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_ENV_DIRS="terraform/envs/staging" \
      TERRAFORM_STUB_LOG="$terraform_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-custom-matrix.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-custom-matrix.out")
    fail "expected custom matrix to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")

  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/staging init -backend=false -input=false -no-color"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/staging validate -no-color"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/dev"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/prod"
}

test_static_mode_skips_environment_init_validate() {
  target="$test_tmp/static-mode"
  make_target_repo "$target"
  terraform_log="$test_tmp/static-mode-terraform.log"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_VALIDATE_MODE=static \
      TERRAFORM_STUB_LOG="$terraform_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-static-mode.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-static-mode.out")
    fail "expected static mode validation to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")

  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/dev init"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/dev validate"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/staging init"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/prod init"
}

test_unsupported_validation_mode_fails_before_terraform_lookup() {
  target="$test_tmp/unsupported-validation-mode"
  make_target_repo "$target"

  set +e
  output=$(
    cd "$target"
    PATH="/usr/bin:/bin" \
      TERRAFORM_VALIDATE_MODE=remote \
      "$repo_root/scripts/validate.sh" 2>&1
  )
  status=$?
  set -e

  [ "$status" -eq 1 ] || fail "expected unsupported validation mode to exit 1"
  assert_contains "$output" "Unsupported TERRAFORM_VALIDATE_MODE: remote. Use full or static."
  assert_not_contains "$output" "terraform not found"
}

test_static_mode_still_runs_optional_policy_scans() {
  target="$test_tmp/static-mode-policy-scans"
  make_target_repo "$target"
  terraform_log="$test_tmp/static-mode-policy-scans-terraform.log"
  checkov_log="$test_tmp/static-mode-policy-scans-checkov.log"
  tflint_log="$test_tmp/static-mode-policy-scans-tflint.log"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_VALIDATE_MODE=static \
      TERRAFORM_ENABLE_CHECKOV=1 \
      TERRAFORM_ENABLE_TFLINT=1 \
      TERRAFORM_STUB_LOG="$terraform_log" \
      CHECKOV_STUB_LOG="$checkov_log" \
      TFLINT_STUB_LOG="$tflint_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-static-mode-policy-scans.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-static-mode-policy-scans.out")
    fail "expected static mode with optional policy scans to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")
  checkov_calls=$(cat "$checkov_log")
  tflint_calls=$(cat "$tflint_log")

  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/dev init"
  assert_contains "$checkov_calls" "-d terraform --quiet"
  assert_contains "$tflint_calls" "--recursive --chdir=terraform"
}

test_public_examples_are_format_checked_as_hcl() {
  target="$test_tmp/public-example-format"
  make_target_repo "$target"
  terraform_log="$test_tmp/public-example-format-terraform.log"

  cat >"$target/terraform/envs/dev/terraform.tfvars.example" <<'EXAMPLE'
environment_name = "dev"
EXAMPLE
  cat >"$target/config/backend.hcl.example" <<'EXAMPLE'
bucket = "replace-with-terraform-state-bucket"
key    = "cloud-infra-template/dev/terraform.tfstate"
EXAMPLE

  run_validation "$target" "$terraform_log" >"$test_tmp/validate-public-example-format.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-public-example-format.out")
    fail "expected public example format checks to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")

  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_contains "$terraform_calls" "fmt -check -diff"
  assert_contains "$terraform_calls" "dev.tfvars"
  assert_contains "$terraform_calls" "backend.tfvars"
}

test_checkov_runs_only_when_enabled() {
  target="$test_tmp/checkov-opt-in"
  make_target_repo "$target"
  checkov_log="$test_tmp/checkov.log"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      CHECKOV_STUB_LOG="$checkov_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-checkov-default.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-checkov-default.out")
    fail "expected default Checkov-disabled validation to pass, got: $output"
  }

  checkov_calls=$(read_file_or_empty "$checkov_log")
  [ -z "$checkov_calls" ] || fail "expected Checkov to be skipped by default"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_ENABLE_CHECKOV=1 \
      CHECKOV_STUB_LOG="$checkov_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-checkov-enabled.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-checkov-enabled.out")
    fail "expected Checkov-enabled validation to pass, got: $output"
  }

  checkov_calls=$(cat "$checkov_log")
  assert_contains "$checkov_calls" "-d terraform --quiet"
}

test_tflint_runs_only_when_enabled() {
  target="$test_tmp/tflint-opt-in"
  make_target_repo "$target"
  tflint_log="$test_tmp/tflint.log"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TFLINT_STUB_LOG="$tflint_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-tflint-default.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-tflint-default.out")
    fail "expected default TFLint-disabled validation to pass, got: $output"
  }

  tflint_calls=$(read_file_or_empty "$tflint_log")
  [ -z "$tflint_calls" ] || fail "expected TFLint to be skipped by default"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_ENABLE_TFLINT=1 \
      TFLINT_STUB_LOG="$tflint_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-tflint-enabled.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-tflint-enabled.out")
    fail "expected TFLint-enabled validation to pass, got: $output"
  }

  tflint_calls=$(cat "$tflint_log")
  assert_contains "$tflint_calls" "--recursive --chdir=terraform"
}

test_tflint_uses_root_config_when_present() {
  target="$test_tmp/tflint-root-config"
  make_target_repo "$target"
  tflint_log="$test_tmp/tflint-root-config.log"

  touch "$target/.tflint.hcl"

  (
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_VALIDATE_MODE=static \
      TERRAFORM_ENABLE_TFLINT=1 \
      TFLINT_STUB_LOG="$tflint_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-tflint-root-config.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-tflint-root-config.out")
    fail "expected TFLint-enabled validation with root config to pass, got: $output"
  }

  tflint_calls=$(cat "$tflint_log")
  assert_contains "$tflint_calls" "--config=$target/.tflint.hcl"
  assert_contains "$tflint_calls" "--recursive --chdir=terraform"
}

test_discovers_terraform_from_home_local_bin() {
  target="$test_tmp/home-local-terraform"
  home_dir="$test_tmp/home-local"
  terraform_log="$test_tmp/home-local-terraform.log"
  make_target_repo "$target"
  make_home_terraform_stub "$home_dir"

  (
    cd "$target"
    PATH="/usr/bin:/bin" \
      HOME="$home_dir" \
      TERRAFORM_STUB_LOG="$terraform_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-home-local-terraform.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-home-local-terraform.out")
    fail "expected Terraform lookup in HOME/.local/bin to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")
  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_contains "$terraform_calls" "-chdir=terraform/envs/dev init -backend=false -input=false -no-color"
}

test_static_mode_discovers_terraform_from_home_local_bin() {
  target="$test_tmp/static-home-local-terraform"
  home_dir="$test_tmp/static-home-local"
  terraform_log="$test_tmp/static-home-local-terraform.log"
  make_target_repo "$target"
  make_home_terraform_stub "$home_dir"

  (
    cd "$target"
    PATH="/usr/bin:/bin" \
      HOME="$home_dir" \
      TERRAFORM_VALIDATE_MODE=static \
      TERRAFORM_STUB_LOG="$terraform_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-static-home-local-terraform.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-static-home-local-terraform.out")
    fail "expected static mode Terraform lookup in HOME/.local/bin to pass, got: $output"
  }

  terraform_calls=$(cat "$terraform_log")
  assert_contains "$terraform_calls" "fmt -check -recursive terraform"
  assert_not_contains "$terraform_calls" "-chdir=terraform/envs/dev init"
}

test_discovers_checkov_from_home_bin_when_enabled() {
  target="$test_tmp/home-bin-checkov"
  home_dir="$test_tmp/home-bin"
  checkov_log="$test_tmp/home-bin-checkov.log"
  make_target_repo "$target"
  make_home_checkov_stub "$home_dir"

  (
    cd "$target"
    PATH="/usr/bin:/bin" \
      HOME="$home_dir" \
      TERRAFORM_BIN="$test_tmp/bin/terraform" \
      TERRAFORM_ENABLE_CHECKOV=1 \
      CHECKOV_STUB_LOG="$checkov_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-home-bin-checkov.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-home-bin-checkov.out")
    fail "expected Checkov lookup in HOME/bin to pass, got: $output"
  }

  checkov_calls=$(cat "$checkov_log")
  assert_contains "$checkov_calls" "-d terraform --quiet"
}

test_discovers_tflint_from_home_bin_when_enabled() {
  target="$test_tmp/home-bin-tflint"
  home_dir="$test_tmp/home-bin-tflint"
  tflint_log="$test_tmp/home-bin-tflint.log"
  make_target_repo "$target"
  make_home_tflint_stub "$home_dir"

  (
    cd "$target"
    PATH="/usr/bin:/bin" \
      HOME="$home_dir" \
      TERRAFORM_BIN="$test_tmp/bin/terraform" \
      TERRAFORM_ENABLE_TFLINT=1 \
      TFLINT_STUB_LOG="$tflint_log" \
      "$repo_root/scripts/validate.sh"
  ) >"$test_tmp/validate-home-bin-tflint.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-home-bin-tflint.out")
    fail "expected TFLint lookup in HOME/bin to pass, got: $output"
  }

  tflint_calls=$(cat "$tflint_log")
  assert_contains "$tflint_calls" "--recursive --chdir=terraform"
}

test_missing_absolute_terraform_bin_reports_executable_path() {
  target="$test_tmp/missing-absolute-terraform"
  missing_terraform="$test_tmp/missing/bin/terraform"
  make_target_repo "$target"

  set +e
  output=$(
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_BIN="$missing_terraform" \
      "$repo_root/scripts/validate.sh" 2>&1
  )
  status=$?
  set -e

  [ "$status" -eq 127 ] || fail "expected missing absolute TERRAFORM_BIN to exit 127"
  assert_contains "$output" "$missing_terraform not found or not executable."
  assert_contains "$output" "Install Terraform CLI >= 1.6.0"
}

test_missing_absolute_tflint_bin_reports_executable_path() {
  target="$test_tmp/missing-absolute-tflint"
  missing_tflint="$test_tmp/missing/bin/tflint"
  make_target_repo "$target"

  set +e
  output=$(
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_ENABLE_TFLINT=1 \
      TFLINT_BIN="$missing_tflint" \
      "$repo_root/scripts/validate.sh" 2>&1
  )
  status=$?
  set -e

  [ "$status" -eq 127 ] || fail "expected missing absolute TFLINT_BIN to exit 127"
  assert_contains "$output" "$missing_tflint not found or not executable."
  assert_contains "$output" "Install TFLint"
}

test_missing_absolute_checkov_bin_reports_executable_path() {
  target="$test_tmp/missing-absolute-checkov"
  missing_checkov="$test_tmp/missing/bin/checkov"
  make_target_repo "$target"

  set +e
  output=$(
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_ENABLE_CHECKOV=1 \
      CHECKOV_BIN="$missing_checkov" \
      "$repo_root/scripts/validate.sh" 2>&1
  )
  status=$?
  set -e

  [ "$status" -eq 127 ] || fail "expected missing absolute CHECKOV_BIN to exit 127"
  assert_contains "$output" "$missing_checkov not found or not executable."
  assert_contains "$output" "Install Checkov"
}

test_non_executable_absolute_checkov_bin_reports_executable_path() {
  target="$test_tmp/non-executable-absolute-checkov"
  checkov_bin="$test_tmp/non-executable/bin/checkov"
  make_target_repo "$target"
  mkdir -p "$(dirname "$checkov_bin")"
  touch "$checkov_bin"

  set +e
  output=$(
    cd "$target"
    PATH="$test_tmp/bin${PATH:+:$PATH}" \
      TERRAFORM_ENABLE_CHECKOV=1 \
      CHECKOV_BIN="$checkov_bin" \
      "$repo_root/scripts/validate.sh" 2>&1
  )
  status=$?
  set -e

  [ "$status" -eq 127 ] || fail "expected non-executable absolute CHECKOV_BIN to exit 127"
  assert_contains "$output" "$checkov_bin not found or not executable."
  assert_contains "$output" "Install Checkov"
}

make_terraform_stub
make_checkov_stub
make_tflint_stub

test_ci_workflow_contract_accepts_repository_workflow
test_ci_workflow_contract_rejects_pull_request_path_filters
test_ci_workflow_contract_rejects_pull_request_target
test_ci_workflow_contract_rejects_secret_usage
test_ci_workflow_contract_rejects_bracket_secret_usage
test_ci_workflow_contract_rejects_write_permissions
test_ci_workflow_contract_rejects_id_token_permissions
test_ci_workflow_contract_rejects_job_permission_override
test_ci_workflow_contract_rejects_persisted_checkout_credentials
test_ci_workflow_contract_rejects_checkout_missing_persist_false
test_ci_workflow_contract_rejects_cloud_credential_action
test_ci_workflow_contract_rejects_cloud_credential_env
test_ci_workflow_contract_rejects_inline_cloud_credential_env
test_ci_workflow_contract_rejects_quoted_inline_cloud_credential_env
test_ci_workflow_contract_rejects_single_quoted_inline_cloud_credential_env
test_gitignore_blocks_public_safety_artifacts
test_gitignore_blocks_nested_public_safety_artifacts
test_gitignore_allows_public_examples
test_allows_public_examples
test_ignores_untracked_forbidden_files
test_rejects_tracked_forbidden_files
test_rejects_only_forbidden_files_when_public_examples_are_tracked
test_default_matrix_runs_all_environment_roots
test_custom_matrix_limits_environment_roots
test_static_mode_skips_environment_init_validate
test_unsupported_validation_mode_fails_before_terraform_lookup
test_static_mode_still_runs_optional_policy_scans
test_public_examples_are_format_checked_as_hcl
test_checkov_runs_only_when_enabled
test_tflint_runs_only_when_enabled
test_tflint_uses_root_config_when_present
test_discovers_terraform_from_home_local_bin
test_static_mode_discovers_terraform_from_home_local_bin
test_discovers_checkov_from_home_bin_when_enabled
test_discovers_tflint_from_home_bin_when_enabled
test_missing_absolute_terraform_bin_reports_executable_path
test_missing_absolute_tflint_bin_reports_executable_path
test_missing_absolute_checkov_bin_reports_executable_path
test_non_executable_absolute_checkov_bin_reports_executable_path

printf '%s\n' "ok - validate public-safety validation contract"
