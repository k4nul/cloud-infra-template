# AWS Cloud Infrastructure Template

Terraform template for AWS network, IAM, and deployment infrastructure.

## Open Source

This repository is prepared for public collaboration under the [MIT License](LICENSE).
See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening issues or pull requests.
Do not commit Terraform state, real `.tfvars`, backend credentials, plans, local
env or Terraform CLI credentials, crash logs, keys, or account-specific
infrastructure details.

## Layout

- `terraform/envs/dev`: development environment root module
- `terraform/envs/staging`: staging environment root module
- `terraform/envs/prod`: production environment root module
- `terraform/modules/environment`: shared environment composition module
- `terraform/modules/network`: VPC and subnet baseline
- `terraform/modules/iam`: deployment role baseline
- `terraform/modules/deployment`: workload security group baseline

## Documentation

- [docs/onboarding.md](docs/onboarding.md): first local checks, safe
  customization, and real-use setup boundaries.
- [docs/infra-contract.md](docs/infra-contract.md): shared input, output,
  example, and validation contract.
- [docs/ci.md](docs/ci.md): pull-request CI triggers, environment, and review
  expectations.
- [docs/maintenance.md](docs/maintenance.md): maintainer workflow, change
  package sizing, validation decision tree, and public-template hygiene.
- [docs/testing.md](docs/testing.md): local validation, CI parity, optional
  TFLint and Checkov scans, and public-safety file checks.
- [docs/troubleshooting.md](docs/troubleshooting.md): common validation failures
  and remediation steps.
- [docs/instructions/phase-gates.json](docs/instructions/phase-gates.json):
  maintainer phase metadata, allowed maintenance work, and validation gates.

## Validate Locally

```bash
./scripts/validate.sh
```

The validation script runs Terraform formatting, public example HCL formatting,
backend-disabled initialization, and `terraform validate` for the checked-in
environment roots.

## Inspect One Environment

```bash
cd terraform/envs/dev
terraform init -backend=false
terraform plan -var-file=terraform.tfvars.example
```

Planning is an operator inspection step and may require normal AWS provider
context. It is not part of the public-safe CI lane.

The checked-in examples do not open workload ingress by default. Add explicit,
public-safe CIDRs to `ingress_cidrs` only when the template consumer has decided
that exposure is required. Set `allow_public_ingress = true` before allowing
`0.0.0.0/0`.

Use `config/backend.hcl.example` as a starting point for backend arguments only
after a consumer-owned environment declares a Terraform backend block. Keep real
backend config untracked. See [docs/onboarding.md](docs/onboarding.md) for the
safe customization flow and [docs/infra-contract.md](docs/infra-contract.md) for
the shared input, output, example, and validation contract for the environment
roots and modules.

## Validation

Pull-request CI runs public-safe validation on every PR so changes outside
Terraform directories cannot bypass the artifact checks. Run the same
backend-disabled validation locally:

```bash
./scripts/validate.sh
```

The validation script checks `dev`, `staging`, and `prod` by default. Set
`TERRAFORM_ENV_DIRS` to a space-separated list of environment root paths to
validate a smaller or custom matrix. Set `TERRAFORM_VALIDATE_MODE=static` when
you need the public-safety and formatting lane without provider registry
downloads. Set `TERRAFORM_ENABLE_TFLINT=1` to add an optional provider-aware
TFLint scan after installing TFLint and running `tflint --init`, or set
`TERRAFORM_ENABLE_CHECKOV=1` to add an optional Checkov policy scan when
`checkov` is installed locally. The script also fails when tracked files include
generated Terraform directories, TFLint plugin cache directories, lockfiles,
state, real `.tfvars`, plans, crash logs, local env or Terraform CLI credential
files, private key material, or real backend config under `config/*.hcl`; only
`.tfvars.example`, `.env.example`, and `config/backend.hcl.example` are intended
to be committed.

See [docs/testing.md](docs/testing.md) for the validation matrix and
[docs/ci.md](docs/ci.md) for pull-request CI behavior, and
[docs/maintenance.md](docs/maintenance.md) for the maintainer workflow and
validation decision tree. See [docs/troubleshooting.md](docs/troubleshooting.md)
for common failure fixes.
