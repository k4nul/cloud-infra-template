# Cloud Infrastructure Contract

## Scope

- Network module: creates the VPC, public subnets, internet gateway, and route table baseline
- IAM module: creates a deployment role with parameterized trust and managed policies
- Deployment module: creates a workload security group for downstream compute or cluster modules; ingress stays closed until callers provide allowed CIDRs, and wildcard ingress requires an explicit opt-in
- Environment roots: keep environment-specific CIDR, region, names, and tags outside reusable modules
- State: configure remote state through backend config, not committed secrets or local state files
- Validation: pull-request CI and `./scripts/validate.sh` must use `terraform init -backend=false` so public checks do not need backend credentials
- Public safety: pull-request CI runs without path filters and the validation script rejects tracked state, plans, real `.tfvars`, private key material, generated Terraform directories, lockfiles, and backend config other than `config/backend.hcl.example`

## Runtime And Provider Contract

- Terraform CLI: environment roots currently require Terraform `>= 1.6.0`; pull-request CI pins `hashicorp/setup-terraform` to Terraform `1.6.6`.
- Provider dependency: each environment root requires `hashicorp/aws` with version constraint `~> 5.0`.
- Module sources: environment roots consume only the checked-in `network`, `iam`, and `deployment` modules through relative paths.
- Lockfiles: `.terraform.lock.hcl` files are not tracked by this template. A provider upgrade package should either keep that public-template policy explicit or intentionally add root lockfiles for every environment in the same change.

## Inputs

The `dev`, `staging`, and `prod` environment roots share the same input contract:

- `region`, `project_name`, and `environment` identify the deployment context.
- `vpc_cidr` and `public_subnets` define the network address plan.
- `trusted_services` and `managed_policy_arns` configure the deployment role.
- `ingress_cidrs` and `allow_public_ingress` control workload ingress; wildcard ingress requires the explicit opt-in.
- `tags` provides caller-owned tags that are merged with the template's project, environment, and managed-by tags.

Reusable modules keep a narrower input surface:

- `network`: `name_prefix`, `vpc_cidr`, `public_subnets`, and `tags`.
- `iam`: `name_prefix`, `trusted_services`, `managed_policy_arns`, and `tags`.
- `deployment`: `name_prefix`, `vpc_id`, `ingress_cidrs`, `allow_public_ingress`, and `tags`.

## Outputs

The environment roots expose these outputs for downstream stacks or examples:

- `vpc_id`
- `public_subnet_ids`
- `deployment_role_arn`
- `workload_security_group_id`

The reusable modules expose only their owned resources:

- `network`: `vpc_id` and `public_subnet_ids`
- `iam`: `deployment_role_arn` and `deployment_role_name`
- `deployment`: `workload_security_group_id`

## Examples

- `terraform/envs/*/terraform.tfvars.example` files are safe public examples and must not contain account IDs, private CIDRs that reveal an organization, real role names, or secrets.
- `config/backend.hcl.example` is the only backend configuration example that should be committed. Real backend config remains operator-owned.
- Example ingress stays closed with `ingress_cidrs = []` and `allow_public_ingress = false`.
- Example validation should use backend-disabled initialization before plan or validate commands.
- CI must run the public-safety file check for every pull request, including documentation or config-only changes.

## Upgrade And Validation Lane

- Keep Terraform and AWS provider constraint changes synchronized across `terraform/envs/dev`, `terraform/envs/staging`, and `terraform/envs/prod`.
- After any provider, module, input, output, or example change, run `terraform fmt -check -recursive terraform` and `./scripts/validate.sh`.
- Run `TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh` only when Checkov is installed locally; public CI keeps this policy scan optional.
