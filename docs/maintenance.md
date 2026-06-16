# Template Maintenance

Use this guide when maintaining the public Terraform template after the initial
validation and module-contract gates are complete. It ties together the safe
change workflow, validation choices, and public-template hygiene rules that are
spread across the onboarding, CI, testing, and contract documents.

## Maintenance Scope

Normal maintenance should keep the template reusable and public-safe:

- keep shared behavior in `terraform/modules/*` and environment-specific wiring
  in `terraform/envs/dev`, `terraform/envs/staging`, and `terraform/envs/prod`;
- keep the `dev`, `staging`, and `prod` root input and output contracts aligned
  unless a deliberate difference is documented in [infra-contract.md](infra-contract.md);
- keep public examples free of account IDs, real backend settings, credentials,
  state, plans, private key material, and real `.tfvars`;
- keep public CI backend-disabled and credential-free;
- keep TFLint and Checkov as local opt-in checks unless the public CI contract is
  intentionally changed in the same package.

Do not introduce new infrastructure scope as routine maintenance. New resource
families, deployment models, backend policy changes, or provider upgrade policy
changes should first get an explicit implementation package and matching contract
updates.

## Change Packages

Prefer one coherent package per change:

- **Module contract update**: update the module implementation, every affected
  environment root, `docs/infra-contract.md`, and examples together.
- **Validation lane update**: update `scripts/validate.sh`, the validation
  contract test, CI documentation, testing documentation, and troubleshooting
  entries together.
- **CI contract update**: update `.github/workflows/terraform-validate.yml`,
  `scripts/validate-ci-workflow.sh`, `docs/ci.md`, and `docs/testing.md`
  together.
- **Documentation update**: update every reader path that would otherwise become
  inconsistent, usually `README.md` plus the relevant files under `docs/`.

Small documentation-only fixes are safe when they clarify existing behavior. If a
documentation change implies a different validation command, CI behavior, input,
output, or example contract, update the owning implementation in a non-docs task.

## Public-Safety Checklist

Before requesting review, verify that the change keeps these files untracked:

- Terraform state, plans, crash logs, and generated `.terraform/` directories.
- Provider lockfiles and `.tflint.d/` plugin cache directories.
- Real `.tfvars`, `.tfvars.json`, `.env`, `.envrc`, Terraform CLI credential
  files, cloud CLI credential directories, and private key material.
- Real backend argument files under `config/*.hcl`.

The only committed variable and backend examples should be
`terraform/envs/*/terraform.tfvars.example`, root or nested `.env.example` files,
and `config/backend.hcl.example`. The validation script enforces this through
the tracked-file public-safety gate.

## Validation Decision Tree

Run the smallest command that answers the maintenance question, then run the full
public lane before review when Terraform behavior or validation behavior changed.

| Change type | Minimum useful command | Before review |
| --- | --- | --- |
| Documentation-only text | `./scripts/validate.sh` when Terraform is available | Explain any exact blocker if validation cannot run |
| Terraform formatting concern | `terraform fmt -check -recursive terraform` | `./scripts/validate.sh` |
| Module, input, output, provider, or example change | `./scripts/validate.sh` | `./scripts/validate.sh` |
| Validation script behavior | `./tests/validate_public_safety_test.sh` | `./tests/validate_public_safety_test.sh` and `./scripts/validate.sh` |
| CI workflow contract | `./scripts/validate-ci-workflow.sh` | `./scripts/validate-ci-workflow.sh`, `./tests/validate_public_safety_test.sh`, and `./scripts/validate.sh` |
| Restricted or offline environment | `TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh` | Rerun `./scripts/validate.sh` when provider registry access is available |
| Optional TFLint scan | `TERRAFORM_ENABLE_TFLINT=1 ./scripts/validate.sh` after `tflint --init` | Keep optional unless the CI contract changes |
| Optional Checkov scan | `TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh` | Keep optional unless the CI contract changes |

Static mode checks the public-safety and formatting lane without provider
downloads. It is useful for phase gates and restricted environments, but it does
not replace backend-disabled `terraform init` and `terraform validate` coverage.

## Environment Matrix

`./scripts/validate.sh` validates these environment roots by default:

```text
terraform/envs/dev terraform/envs/staging terraform/envs/prod
```

Those roots instantiate the `environment` composition module, which wires the
lower-level `network`, `iam`, and `deployment` modules. A new lower-level module
is not fully covered until it is wired into the composition module or an explicit
root module path is added through `TERRAFORM_ENV_DIRS`.

Use a custom matrix only when narrowing a local check intentionally:

```bash
TERRAFORM_ENV_DIRS="terraform/envs/dev" ./scripts/validate.sh
```

## Provider And Terraform Upgrade Playbook

Treat provider and Terraform version changes as one upgrade package, not as an
incidental maintenance edit. Before changing constraints, compare the current
runtime contract in [infra-contract.md](infra-contract.md):

- environment roots require Terraform `>= 1.6.0`;
- pull-request CI pins `hashicorp/setup-terraform` to Terraform `1.6.6`;
- each environment root requires `hashicorp/aws` with version constraint
  `~> 5.0`;
- `.terraform.lock.hcl` files are intentionally not tracked by this public
  template.

For a Terraform CLI upgrade:

1. Update the `required_version` constraint in `terraform/envs/dev`,
   `terraform/envs/staging`, and `terraform/envs/prod` together.
2. Update the CI `terraform_version` pin in
   `.github/workflows/terraform-validate.yml` when the public validation runtime
   should move with the template constraint.
3. Update [infra-contract.md](infra-contract.md), [ci.md](ci.md), and
   [troubleshooting.md](troubleshooting.md) so local and CI version guidance stay
   aligned.
4. Run `terraform fmt -check -recursive terraform` and `./scripts/validate.sh`.

For an AWS provider upgrade:

1. Update the `hashicorp/aws` constraint in every environment root in the same
   change.
2. Keep the lockfile policy explicit. Either continue leaving
   `.terraform.lock.hcl` untracked for this public template, or intentionally add
   lockfiles for every environment root and update `.gitignore`,
   [infra-contract.md](infra-contract.md), [testing.md](testing.md), and
   [ci.md](ci.md) in the same package.
3. Run the full validation script because backend-disabled `terraform init`
   still needs provider discovery in full mode.
4. If the environment blocks provider downloads, run
   `TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh` as a local public-safety
   check and record that full validation remains blocked until registry access is
   available.

Do not commit generated `.terraform/` directories, downloaded provider plugins,
real backend config, real `.tfvars`, plans, state, local or cloud CLI
credentials, or provider lockfiles unless the lockfile policy is intentionally
changed for every environment root in the same package.

## Backend And Real Use Boundaries

The checked-in environment roots intentionally do not declare a backend block.
Consumers that adopt remote state should do that in consumer-owned environment
configuration or a downstream fork. Keep backend arguments in an untracked local
copy of `config/backend.hcl.example`, and change the backend `key` for each real
environment.

Public validation must continue to use:

```bash
terraform init -backend=false -input=false -no-color
```

Do not add cloud credentials, repository secrets, `pull_request_target`, write
permissions, or pull-request path filters to the public validation workflow.

## Review Notes

When reviewing maintenance changes, check that:

- README, onboarding, testing, CI, troubleshooting, and infra contract docs still
  describe the same behavior;
- examples remain safe to publish and keep workload ingress closed by default;
- any wildcard ingress example also requires `allow_public_ingress = true`;
- optional scanners remain opt-in in public CI;
- the pull-request template validation section lists the commands actually run
  or the exact blocker.

See [testing.md](testing.md) for command details, [ci.md](ci.md) for workflow
expectations, and [troubleshooting.md](troubleshooting.md) for common failure
fixes.
