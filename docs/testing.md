# Testing And Validation

This repository uses one public-safe validation lane for local development and
pull-request CI. The lane is designed to run without repository secrets, remote
state credentials, or committed operator-specific Terraform files.

## Standard Commands

Run the full local validation from the repository root:

```bash
./scripts/validate.sh
```

For a fast formatting check only:

```bash
terraform fmt -check -recursive terraform
```

To test the validation script contract without downloading providers:

```bash
./tests/validate_public_safety_test.sh
```

To run the public-safety and formatting lane without Terraform provider
registry downloads:

```bash
TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh
```

`./scripts/validate.sh` uses `TERRAFORM_BIN` when set and otherwise runs
`terraform`. If the command is not already on `PATH`, the script also checks
`$HOME/.local/bin`, `$HOME/bin`, and `/usr/local/bin` before reporting a missing
tool. This keeps local cron and automation checks aligned with interactive
shells that install Terraform under a user-local directory.

Run the full validation script after Terraform, example, module, input, or
output changes. The standalone formatting command is useful when you want to
check formatting before running the full environment matrix. Static mode is for
phase gates and restricted environments where the public-safety and formatting
contract must run without provider downloads; it does not replace full
`terraform init -backend=false` and `terraform validate` coverage.

The default validation matrix covers modules through the checked-in environment
roots that instantiate the shared `terraform/modules/environment` composition
module. That composition module then wires the lower-level `network`, `iam`, and
`deployment` modules. If a change adds a new lower-level module or leaves a
module temporarily unreferenced by `dev`, `staging`, or `prod`, wire that module
into the environment composition module or add an explicit root module path to
`TERRAFORM_ENV_DIRS` before treating `./scripts/validate.sh` as full Terraform
validation for it.

## What `./scripts/validate.sh` Checks

The script performs these checks in order:

1. Uses `git ls-files` to reject tracked generated, state, plan, secret, real
   `.tfvars`, lockfile, crash log, local env or Terraform CLI credential,
   private key, or real backend files under `config/*.hcl`.
2. Runs `terraform fmt -check -recursive terraform`.
3. Unless `TERRAFORM_VALIDATE_MODE=static` is set, runs
   `terraform init -backend=false -input=false -no-color` for each selected
   environment root.
4. Unless `TERRAFORM_VALIDATE_MODE=static` is set, runs
   `terraform validate -no-color` for each selected environment root.
5. Runs recursive TFLint against `terraform/`, using the root `.tflint.hcl`
   config when present, only when `TERRAFORM_ENABLE_TFLINT=1` is set.
6. Runs `checkov -d terraform --quiet` only when
   `TERRAFORM_ENABLE_CHECKOV=1` is set.

By default, the environment matrix is:

```text
terraform/envs/dev terraform/envs/staging terraform/envs/prod
```

To validate a smaller matrix locally:

```bash
TERRAFORM_ENV_DIRS="terraform/envs/dev" ./scripts/validate.sh
```

`./tests/validate_public_safety_test.sh` covers the validation wrapper behavior
around the tracked-file gate, the default matrix, custom `TERRAFORM_ENV_DIRS`,
and the optional TFLint and Checkov opt-ins by running against temporary
repositories with stubbed tool commands.

## Pull-Request CI Parity

`.github/workflows/terraform-validate.yml` runs the validation contract test and
then the same validation script for pull requests, pushes to `main`, and manual
workflow dispatches. The workflow has no pull-request path filters, pins
Terraform `1.6.6`, disables Terraform input prompts, and keeps
`TERRAFORM_ENABLE_TFLINT=0` and `TERRAFORM_ENABLE_CHECKOV=0` so public CI does
not require extra scanner installation, plugin downloads, or credentials.

Do not add pull-request path filters that would let documentation-only or
configuration-only changes skip the public-safety file check.

See [ci.md](ci.md) for the workflow triggers, pinned Terraform version,
environment variables, and pull-request checklist expectations.

## Optional Policy Scan

TFLint is optional and local by default. Install TFLint, run `tflint --init`
from the repository root to install the configured AWS ruleset plugin, then run:

```bash
TERRAFORM_ENABLE_TFLINT=1 ./scripts/validate.sh
```

If TFLint is requested but not installed, the script exits with status `127`.
Set `TFLINT_BIN` when TFLint is installed outside `PATH`. When `.tflint.hcl` is
present at the repository root, the validation script passes it to TFLint with an
absolute `--config` path so recursive scans use the checked-in provider-aware
ruleset configuration. A missing TFLint binary or uninitialized plugin cache is
an environment tooling blocker, not a Terraform contract failure. Keep the
`.tflint.d/` plugin cache untracked.

Checkov is optional and local by default:

```bash
TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh
```

If Checkov is requested but not installed, the script exits with status `127`.
Set `CHECKOV_BIN` when Checkov is installed outside `PATH`. A missing Checkov
binary is an environment tooling blocker, not a Terraform contract failure.

## Files That Must Stay Untracked

The validation script rejects these tracked file classes:

- `.terraform/` directories.
- `.terraform.lock.hcl` files.
- `.tflint.d/` plugin cache directories.
- Terraform state files.
- Terraform plan files.
- Real `.tfvars` or `.tfvars.json` files.
- Terraform crash logs.
- Local env and Terraform CLI credential files such as `.env`, `.envrc`,
  `.terraformrc`, `terraform.rc`, or `.terraform.d/` contents.
- Private key material such as `.pem`, `.key`, `.p12`, `.pfx`, `.p8`, `.jks`,
  `.keystore`, `id_rsa`, `id_dsa`, `id_ecdsa`, or `id_ed25519` files.
- Real backend config under `config/*.hcl`.

The allowed public examples are files that end in `.tfvars.example`, root or
nested `.env.example` files, and `config/backend.hcl.example`.
