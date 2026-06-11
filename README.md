# Cloud Infrastructure Template

Terraform template for cloud network, IAM, and deployment infrastructure.

## Open Source

This repository is prepared for public collaboration under the [MIT License](LICENSE).
See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before opening issues or pull requests.
Do not commit Terraform state, real `.tfvars`, backend credentials, plans, keys,
or account-specific infrastructure details.

## Layout

- `terraform/envs/dev`: development environment root module
- `terraform/envs/staging`: staging environment root module
- `terraform/envs/prod`: production environment root module
- `terraform/modules/network`: VPC and subnet baseline
- `terraform/modules/iam`: deployment role baseline
- `terraform/modules/deployment`: workload security group baseline

## Quick Use

```bash
cd terraform/envs/dev
terraform init -backend=false
terraform plan -var-file=terraform.tfvars.example
```

The checked-in examples do not open workload ingress by default. Add explicit,
public-safe CIDRs to `ingress_cidrs` only when the template consumer has decided
that exposure is required. Set `allow_public_ingress = true` before allowing
`0.0.0.0/0`.

Use `config/backend.hcl.example` as a starting point when wiring remote state.

## Validation

Run the same backend-disabled validation used by pull-request CI:

```bash
./scripts/validate.sh
```
