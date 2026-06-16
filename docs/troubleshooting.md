# Troubleshooting

Use this guide when local validation or pull-request CI fails. The commands
below assume they are run from the repository root unless noted otherwise.
For workflow triggers and CI environment details, see [ci.md](ci.md).
For choosing the right maintenance validation command before review, see
[maintenance.md](maintenance.md).

## `terraform: not found`

Install Terraform CLI `>= 1.6.0` and rerun:

```bash
terraform fmt -check -recursive terraform
./scripts/validate.sh
```

The validation script first uses `TERRAFORM_BIN` when set, then `terraform` from
`PATH`, then common local install directories: `$HOME/.local/bin`, `$HOME/bin`,
and `/usr/local/bin`. If Terraform is already installed outside those locations,
run with an explicit binary path:

```bash
TERRAFORM_BIN=/path/to/terraform ./scripts/validate.sh
```

Phase gates and restricted environments can use the validation script's static
mode so Terraform discovery uses the same lookup path while avoiding provider
registry downloads:

```bash
TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh
```

CI currently uses Terraform `1.6.6`, so matching that version locally is the
closest parity check.

## Public-Safety Validation Failed

`./scripts/validate.sh` prints this failure when a forbidden file is tracked by
Git. Remove the tracked file from the commit and keep it local instead.

Common fixes:

- Move real variable values to an untracked `terraform.tfvars`.
- Keep only `terraform.tfvars.example` files committed.
- Move real remote state settings under `config/*.hcl` to an untracked local
  file, such as `config/backend.hcl`.
- Keep only `config/backend.hcl.example` committed.
- Remove `.terraform/`, `.tflint.d/`, state, plan, lockfile, crash log, local
  env or Terraform CLI credential files, and key material from the index.

The `.gitignore` already ignores these local operator files. If one appears in
validation output, it was force-added or committed before the ignore rule was in
place.

## Terraform Formatting Failed

Run the formatter, then rerun the check:

```bash
terraform fmt -recursive terraform
terraform fmt -check -recursive terraform
```

Formatting changes are source changes, so they should be made in implementation
or lint-triage work, not in a docs-only run.

## Backend Or Credential Errors During Validation

The standard validation path should not require remote state credentials because
the script runs:

```bash
terraform init -backend=false -input=false -no-color
```

If validation prompts for backend or credential input, check that the command is
running through `./scripts/validate.sh` or that manual Terraform commands include
`-backend=false` for public-safe validation. The checked-in environment roots do
not declare a backend block; remote state wiring belongs in consumer-owned
environment configuration or a downstream fork.

## Provider Registry Access Failed

`./scripts/validate.sh` still runs `terraform init -backend=false` in full mode,
so Terraform may contact `registry.terraform.io` to resolve the AWS provider.
If the environment blocks DNS or network access, run the static lane for
public-safety and formatting checks:

```bash
TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh
```

Static mode is not a full replacement for provider validation. Rerun
`./scripts/validate.sh` when provider registry access is available.

## Invalid Or Unsafe Ingress CIDRs

`terraform/modules/deployment` validates that every `ingress_cidrs` entry is an
IPv4 CIDR block. The workload security group also requires
`allow_public_ingress = true` before `0.0.0.0/0` can be used.

For the public examples, keep:

```hcl
ingress_cidrs        = []
allow_public_ingress = false
```

Add real ingress only in untracked operator-owned variable files unless the
example is intentionally documenting a safe public CIDR.

## Optional TFLint Failure

TFLint runs only when explicitly requested:

```bash
TERRAFORM_ENABLE_TFLINT=1 ./scripts/validate.sh
```

If the command reports that `tflint` was not found, install TFLint, set
`TFLINT_BIN=/path/to/tflint`, or rerun the standard public CI lane without that
environment variable. If the configured AWS ruleset plugin is missing, run
`tflint --init` from the repository root and rerun validation. The validation
script passes the repository root `.tflint.hcl` as an explicit config file when
it exists. Keep the generated `.tflint.d/` plugin cache untracked.

## Optional Checkov Failure

Checkov runs only when explicitly requested:

```bash
TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh
```

If the command reports that `checkov` was not found, install Checkov, set
`CHECKOV_BIN=/path/to/checkov`, or rerun the standard public CI lane without
that environment variable.

## Missing Environment Directory

When using `TERRAFORM_ENV_DIRS`, provide repository-relative root module paths:

```bash
TERRAFORM_ENV_DIRS="terraform/envs/dev terraform/envs/staging" ./scripts/validate.sh
```

The script fails fast if any selected path does not exist.
