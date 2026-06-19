# Pull-Request CI

This repository keeps one public-safe CI lane for Terraform template changes.
The lane is intentionally the same shape as local validation so contributors can
reproduce failures before opening or updating a pull request.

## Workflow

The workflow lives at `.github/workflows/terraform-validate.yml` and runs for:

- every pull request,
- pushes to `main`,
- manual `workflow_dispatch` runs.

The workflow has no pull-request path filters. Documentation, GitHub template,
and configuration-only changes still run the validation contract test and the
public-safety file check in `./scripts/validate.sh`, which prevents accidental
commits of local Terraform artifacts or operator-owned secrets.

The validation job cancels older in-progress runs for the same Git ref and has a
15-minute timeout. Treat a cancellation as superseded CI for that ref, and treat
a timeout as a validation environment or provider-download blocker until the
failed step proves otherwise.

## CI Environment

The workflow runs on `ubuntu-latest` and pins Terraform through
`hashicorp/setup-terraform`:

```text
terraform_version: "1.6.6"
```

It sets these environment variables before running validation:

```text
CHECKPOINT_DISABLE=1
TF_IN_AUTOMATION=1
TF_INPUT=0
TERRAFORM_ENABLE_CHECKOV=0
TERRAFORM_ENABLE_TFLINT=0
```

TFLint and Checkov are disabled in public CI so the required lane has no extra
scanner dependency. Run the optional local TFLint scan with
`TERRAFORM_ENABLE_TFLINT=1 ./scripts/validate.sh` after installing TFLint and
running `tflint --init`; the checked-in `.tflint.hcl` pins the AWS ruleset
plugin `tflint-ruleset-aws` `0.32.0`. Run the optional local Checkov scan with
`TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh` when Checkov is installed.

## Validation Commands

CI first verifies that the workflow still matches the public-safe contract:

```bash
./scripts/validate-ci-workflow.sh
```

That check rejects `pull_request_target`, pull-request path filters, repository
secret references including alternate secret-context syntax, persisted checkout
credentials on every checkout step, job-level permission overrides, cloud
credential setup actions or credential environment variables including inline
YAML maps with quoted or unquoted keys, missing scanner opt-out flags, Terraform
version drift, and a missing public validation step.

CI then runs the validation contract test:

```bash
./tests/validate_public_safety_test.sh
```

That test uses temporary Git repositories and stubbed Terraform, TFLint, and
Checkov commands to verify the public-safety file gate, the default environment
matrix, custom `TERRAFORM_ENV_DIRS` behavior, and the optional TFLint and
Checkov opt-ins without needing provider downloads. It also checks that unsafe
workflow variants are rejected by the workflow contract validator.

CI then runs the public-safe Terraform validation:

```bash
./scripts/validate.sh
```

The validation script:

1. rejects tracked Terraform state, plans, real `.tfvars`, crash logs, local
   env, Terraform CLI credential files, cloud CLI credential directories,
   private key material, generated `.terraform/` directories, `.tflint.d/`
   plugin cache directories, lockfiles, and real backend config under
   `config/*.hcl`,
2. runs `terraform fmt -check -recursive terraform`,
3. copies committed `.tfvars.example` and `config/backend.hcl.example` files to
   temporary `.tfvars` names and runs `terraform fmt -check -diff` against those
   parseable copies,
4. initializes each selected environment root with `terraform init
   -backend=false -input=false -no-color`,
5. runs `terraform validate -no-color` for each selected environment root,
6. skips TFLint unless `TERRAFORM_ENABLE_TFLINT=1` is set,
7. skips Checkov unless `TERRAFORM_ENABLE_CHECKOV=1` is set.

The default environment matrix is:

```text
terraform/envs/dev terraform/envs/staging terraform/envs/prod
```

Phase gates or restricted local environments can run
`TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh` to exercise the
public-safety and formatting contract without provider registry downloads.
Static mode skips only environment-root `terraform init` and `terraform
validate`; optional TFLint and Checkov scans still run when their opt-in
variables are enabled. Public CI intentionally runs the default full mode.

## Pull-Request Expectations

Before requesting review:

- run `./scripts/validate.sh` locally, or explain the exact blocker in the pull
  request validation section,
- keep only public examples committed, such as `terraform.tfvars.example` and
  `config/backend.hcl.example`,
- keep real `.tfvars`, backend config, state, plans, crash logs, local env,
  Terraform CLI credential files, cloud CLI credential directories, provider
  lockfiles, generated Terraform directories, keys, and account-specific values
  untracked,
- update `docs/infra-contract.md` when module inputs, outputs, examples,
  validation behavior, or environment-root wiring changes,
- wire new or temporarily unreferenced modules into an environment root or an
  explicit `TERRAFORM_ENV_DIRS` validation path before relying on the default
  environment matrix,
- use [maintenance.md](maintenance.md) to keep the change package and validation
  evidence aligned.

If CI fails, start with [troubleshooting.md](troubleshooting.md). The most common
public CI failures are a validation contract regression, missing formatting, an
accidentally tracked local Terraform artifact, or a change that updates one
environment root without keeping the shared root contract aligned.
