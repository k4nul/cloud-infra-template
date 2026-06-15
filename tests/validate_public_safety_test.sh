#!/usr/bin/env sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/cloud-infra-template-test.XXXXXX")

cleanup() {
  rm -rf "$test_tmp"
}

trap cleanup EXIT INT TERM

fail() {
  echo "not ok - $1" >&2
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
    echo "unexpected terraform command: $*" >&2
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
    PATH="$test_tmp/bin:$PATH" TERRAFORM_STUB_LOG="$terraform_log" "$repo_root/scripts/validate.sh"
  )
}

test_allows_public_examples() {
  target="$test_tmp/allows-public-examples"
  make_target_repo "$target"

  mkdir -p "$target/terraform/envs/dev"
  touch "$target/config/backend.hcl.example"
  touch "$target/terraform/envs/dev/terraform.tfvars.example"

  (
    cd "$target"
    git add config/backend.hcl.example terraform/envs/dev/terraform.tfvars.example
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

  run_validation "$target" >"$test_tmp/validate-untracked.out" 2>&1 || {
    output=$(cat "$test_tmp/validate-untracked.out")
    fail "expected untracked forbidden files to pass, got: $output"
  }
}

test_rejects_tracked_forbidden_files() {
  target="$test_tmp/rejects-forbidden"
  make_target_repo "$target"

  mkdir -p "$target/terraform/envs/dev/.terraform/providers" \
    "$target/nested"
  touch "$target/.terraform.lock.hcl"
  touch "$target/terraform/envs/dev/.terraform/providers/cache.txt"
  touch "$target/terraform/envs/dev/terraform.tfvars"
  touch "$target/terraform/envs/dev/terraform.tfvars.json"
  touch "$target/terraform.tfstate"
  touch "$target/terraform.tfstate.backup"
  touch "$target/app.tfplan"
  touch "$target/app.plan"
  touch "$target/plan-dev.out"
  touch "$target/nested/plan-prod.out"
  touch "$target/secret.pem"
  touch "$target/secret.key"
  touch "$target/secret.p12"
  touch "$target/config/prod.hcl"

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
  assert_contains "$output" ".terraform.lock.hcl"
  assert_contains "$output" "terraform/envs/dev/.terraform/providers/cache.txt"
  assert_contains "$output" "terraform/envs/dev/terraform.tfvars"
  assert_contains "$output" "terraform/envs/dev/terraform.tfvars.json"
  assert_contains "$output" "terraform.tfstate"
  assert_contains "$output" "terraform.tfstate.backup"
  assert_contains "$output" "app.tfplan"
  assert_contains "$output" "app.plan"
  assert_contains "$output" "plan-dev.out"
  assert_contains "$output" "nested/plan-prod.out"
  assert_contains "$output" "secret.pem"
  assert_contains "$output" "secret.key"
  assert_contains "$output" "secret.p12"
  assert_contains "$output" "config/prod.hcl"
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
    PATH="$test_tmp/bin:$PATH" \
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

test_checkov_runs_only_when_enabled() {
  target="$test_tmp/checkov-opt-in"
  make_target_repo "$target"
  checkov_log="$test_tmp/checkov.log"

  (
    cd "$target"
    PATH="$test_tmp/bin:$PATH" \
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
    PATH="$test_tmp/bin:$PATH" \
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

make_terraform_stub
make_checkov_stub

test_allows_public_examples
test_ignores_untracked_forbidden_files
test_rejects_tracked_forbidden_files
test_default_matrix_runs_all_environment_roots
test_custom_matrix_limits_environment_roots
test_checkov_runs_only_when_enabled

echo "ok - validate public-safety validation contract"
