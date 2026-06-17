# Cloud Infrastructure Contract

## Scope

- Network module: creates the VPC, public subnets with public IP assignment on launch, internet gateway, and public route table baseline
- IAM module: creates a deployment role with parameterized trust and managed policies
- Deployment module: creates a workload security group for downstream compute or cluster modules; inbound TCP/80 stays closed until callers provide allowed CIDRs, wildcard ingress requires an explicit opt-in, and egress allows outbound traffic to `0.0.0.0/0`
- Environment composition module: wires the network, IAM, and deployment modules with the shared name/tag convention and workload ingress controls
- Environment roots: keep provider configuration, environment-specific defaults, CIDR, region, names, and tags outside lower-level reusable modules
- State: keep public validation backend-disabled. Consumers that adopt remote state should declare backend blocks in consumer-owned environment configuration and keep backend arguments in untracked config, not committed secrets or local state files.
- Validation: pull-request CI and `./scripts/validate.sh` must use `terraform init -backend=false` so public checks do not need backend credentials. The validation script must also format-check committed `.tfvars.example` and `config/backend.hcl.example` files through temporary Terraform-readable copies.
- Optional lint: provider-aware TFLint checks are local opt-in through `TERRAFORM_ENABLE_TFLINT=1`; public CI and standard validation must not require TFLint, plugin downloads, credentials, or backend state. The checked-in `.tflint.hcl` enables module-aware linting and pins `tflint-ruleset-aws` `0.32.0`; validation passes that file to TFLint with an absolute `--config` path when it is present. The generated `.tflint.d/` plugin cache remains untracked.
- Public safety: pull-request CI runs without path filters and the validation script rejects tracked state, plans, real `.tfvars`, private key material, generated Terraform directories, TFLint plugin cache directories, lockfiles, crash logs, local env, Terraform CLI credential files, cloud CLI credential directories, and real backend config under `config/*.hcl` other than `config/backend.hcl.example`

## Runtime And Provider Contract

- Terraform CLI: environment roots currently require Terraform `>= 1.6.0`; pull-request CI pins `hashicorp/setup-terraform` to Terraform `1.6.6`.
- Provider dependency: each environment root requires `hashicorp/aws` with version constraint `~> 5.0`.
- Module sources: environment roots consume the checked-in `environment` composition module through relative paths; that module consumes the checked-in `network`, `iam`, and `deployment` modules through relative paths.
- Lockfiles: `.terraform.lock.hcl` files are not tracked by this template. A provider upgrade package should either keep that public-template policy explicit or intentionally add root lockfiles for every environment in the same change.

## Reader Workflow

- Start with [docs/onboarding.md](onboarding.md) for first-run validation and
  safe local customization.
- Use this contract when changing module inputs, outputs, examples, or
  environment root wiring.
- Use [docs/testing.md](testing.md) for the exact local and CI validation lane.
- Use [docs/troubleshooting.md](troubleshooting.md) when validation fails.

## Inputs

The `dev`, `staging`, and `prod` environment roots share the same input contract:

- `region`, `project_name`, and `environment` identify the deployment context.
- `vpc_cidr` and `public_subnets` define the network address plan.
- `trusted_services` and `managed_policy_arns` configure the deployment role.
- `ingress_cidrs` and `allow_public_ingress` control workload ingress; wildcard ingress requires the explicit opt-in.
- `tags` provides caller-owned tags that are merged with the template's project, environment, and managed-by tags.

The committed `terraform.tfvars.example` files set the environment name, CIDR
map, ingress defaults, and tags. They rely on environment-root defaults for
`trusted_services = ["ec2.amazonaws.com"]` and `managed_policy_arns = []` until a
consumer provides operator-owned IAM values in an untracked variable file.

Reusable modules keep narrower input surfaces:

- `environment`: `project_name`, `environment`, `vpc_cidr`, `public_subnets`, `trusted_services`, `managed_policy_arns`, `ingress_cidrs`, `allow_public_ingress`, and `tags`.
- `network`: `name_prefix`, `vpc_cidr`, `public_subnets`, and `tags`.
- `iam`: `name_prefix`, `trusted_services`, `managed_policy_arns`, and `tags`.
- `deployment`: `name_prefix`, `vpc_id`, `ingress_cidrs`, `allow_public_ingress`, and `tags`.

## Outputs

The environment roots expose these outputs for downstream stacks or examples:

- `vpc_id`
- `public_subnet_ids`
- `deployment_role_arn`
- `workload_security_group_id`

The environment composition module preserves the root output contract by exposing:

- `vpc_id`
- `public_subnet_ids`
- `deployment_role_arn`
- `workload_security_group_id`

The lower-level reusable modules expose only their owned resources:

- `network`: `vpc_id` and `public_subnet_ids`
- `iam`: `deployment_role_arn` and `deployment_role_name`
- `deployment`: `workload_security_group_id`

## Examples

- `terraform/envs/*/terraform.tfvars.example` files are safe public examples and must not contain account IDs, private CIDRs that reveal an organization, real role names, or secrets.
- `config/backend.hcl.example` is the only backend argument example that should be committed. The checked-in environment roots do not declare a backend block. Real backend config remains operator-owned, and the backend state `key` should be changed per environment in the untracked local copy when a consumer wires remote state.
- Example ingress stays closed with `ingress_cidrs = []` and `allow_public_ingress = false`.
- Example validation should format-check committed example variable and backend
  files and use backend-disabled initialization before manual plan or validate
  commands.
- CI must run the public-safety file check for every pull request, including documentation or config-only changes.

## Upgrade And Validation Lane

- Keep Terraform and AWS provider constraint changes synchronized across `terraform/envs/dev`, `terraform/envs/staging`, and `terraform/envs/prod`.
- After any provider, module, input, output, or example change, run `terraform fmt -check -recursive terraform` and `./scripts/validate.sh`.
- The default validation matrix validates modules through `dev`, `staging`, and `prod`. New or temporarily unreferenced lower-level modules need composition-module wiring or an explicit root module path in `TERRAFORM_ENV_DIRS` before they are covered by full Terraform validation.
- Use `TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh` only for the no-provider public-safety and formatting lane used by phase gates or restricted environments; it intentionally skips environment root `init` and `validate`, while still running optional TFLint or Checkov scans when their opt-in variables are enabled.
- Run `TERRAFORM_ENABLE_TFLINT=1 ./scripts/validate.sh` only when TFLint is installed and `tflint --init` has prepared the checked-in `.tflint.hcl` AWS ruleset plugin; public CI keeps this provider-aware lint lane optional.
- Run `TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh` only when Checkov is installed locally; public CI keeps this policy scan optional.
