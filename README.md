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

Use `config/backend.hcl.example` as a starting point when wiring remote state.
