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

`./scripts/validate.sh` uses `TERRAFORM_BIN` when set and otherwise runs
`terraform`. If the command is not already on `PATH`, the script also checks
`$HOME/.local/bin`, `$HOME/bin`, and `/usr/local/bin` before reporting a missing
tool. This keeps local cron and automation checks aligned with interactive
shells that install Terraform under a user-local directory.

Run the full validation script after Terraform, example, module, input, or
output changes. The standalone formatting command is useful when you want to
check formatting before running the full environment matrix.

## What `./scripts/validate.sh` Checks

The script performs these checks in order:

1. Uses `git ls-files` to reject tracked generated, state, plan, secret, real
   `.tfvars`, lockfile, private key, or real backend files under `config/*.hcl`.
2. Runs `terraform fmt -check -recursive terraform`.
3. Runs `terraform init -backend=false -input=false -no-color` for each selected
   environment root.
4. Runs `terraform validate -no-color` for each selected environment root.
5. Runs `checkov -d terraform --quiet` only when
   `TERRAFORM_ENABLE_CHECKOV=1` is set.

By default, the environment matrix is:

```text
terraform/envs/dev terraform/envs/staging terraform/envs/prod
```

To validate a smaller matrix locally:

```bash
TERRAFORM_ENV_DIRS="terraform/envs/dev" ./scripts/validate.sh
```

## Pull-Request CI Parity

`.github/workflows/terraform-validate.yml` runs the same script for pull
requests, pushes to `main`, and manual workflow dispatches. The workflow has no
pull-request path filters, pins Terraform `1.6.6`, disables Terraform input
prompts, and keeps
`TERRAFORM_ENABLE_CHECKOV=0` so public CI does not require extra policy-scanner
installation or credentials.

Do not add pull-request path filters that would let documentation-only or
configuration-only changes skip the public-safety file check.

## Optional Policy Scan

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
- Terraform state files.
- Terraform plan files.
- Real `.tfvars` or `.tfvars.json` files.
- Private key material such as `.pem`, `.key`, or `.p12` files.
- Real backend config under `config/*.hcl`.

The allowed public examples are `terraform.tfvars.example` files and
`config/backend.hcl.example`.
