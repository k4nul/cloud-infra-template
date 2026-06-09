# Cloud Infrastructure Template

Terraform template for cloud network, IAM, and deployment infrastructure.

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
