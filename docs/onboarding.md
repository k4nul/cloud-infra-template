# Onboarding

This template is a public-safe Terraform starting point for network, IAM, and
deployment infrastructure. It keeps reusable behavior in modules and keeps
environment-specific values in the `dev`, `staging`, and `prod` root modules.

## Prerequisites

- Terraform CLI `>= 1.6.0`.
- Git, for the tracked-file safety checks in `./scripts/validate.sh`.
- AWS credentials only when an operator intentionally runs real plans or
  applies against an account. The default validation path uses
  `terraform init -backend=false` and does not require backend credentials.

## Repository Map

- `terraform/envs/dev`: development root module.
- `terraform/envs/staging`: staging root module.
- `terraform/envs/prod`: production root module.
- `terraform/modules/network`: VPC, public subnets, internet gateway, and public
  route table baseline.
- `terraform/modules/iam`: deployment role baseline.
- `terraform/modules/deployment`: workload security group baseline.
- `config/backend.hcl.example`: public-safe backend argument example only.
- `docs/infra-contract.md`: input, output, example, and validation contract.
- `docs/ci.md`: pull-request CI triggers, environment, and review expectations.
- `docs/maintenance.md`: maintainer workflow, change package sizing, validation
  decision tree, and public-template hygiene.
- `docs/testing.md`: local and CI validation guidance.
- `docs/troubleshooting.md`: common validation failures and fixes.
- `docs/instructions/phase-gates.json`: maintainer phase metadata, allowed
  maintenance work, and validation gates.

## First Local Check

From the repository root, run the same public-safe validation used by CI:

```bash
./scripts/validate.sh
```

The script validates all checked-in environment roots by default and initializes
Terraform with `-backend=false`, so it should not contact a remote state backend.

## Inspect One Environment

To inspect the development root without configuring remote state:

```bash
cd terraform/envs/dev
terraform init -backend=false
terraform plan -var-file=terraform.tfvars.example
```

This manual plan path is for operator inspection. It disables remote backend
initialization, but it can still require normal AWS provider download access and
AWS credential context because the environment root configures the AWS provider.
Use `./scripts/validate.sh` for the public-safe validation lane, or
`TERRAFORM_VALIDATE_MODE=static ./scripts/validate.sh` when provider registry
access is unavailable.

The checked-in examples are intentionally safe to publish. They keep
`ingress_cidrs = []` and `allow_public_ingress = false`, so the workload security
group starts with no inbound workload rule. If a consumer needs inbound access,
use explicit CIDR ranges. Setting `0.0.0.0/0` also requires
`allow_public_ingress = true`.

## Customizing For Real Use

Keep organization-specific values out of the repository:

1. Copy an environment example to an untracked local file, such as
   `terraform/envs/dev/terraform.tfvars`.
2. Replace the sample CIDR blocks, tags, trust services, and policy ARNs with
   operator-owned values.
3. Copy `config/backend.hcl.example` to untracked `config/backend.hcl` only when
   wiring real remote state in a consumer-owned environment.
4. Update the backend `key` in the local copy for the environment you are
   initializing, such as `cloud-infra-template/staging/terraform.tfstate` for
   staging or `cloud-infra-template/prod/terraform.tfstate` for production.
5. Declare the backend block in the consumer-owned environment configuration or
   downstream fork. The checked-in root modules intentionally do not declare a
   backend block so public validation can stay backend-disabled.
6. From an environment root, initialize with the local backend file only after
   the backend block exists and real backend access is intended:

```bash
terraform init -backend-config=../../../config/backend.hcl
```

Real `.tfvars`, backend config, state, plans, crash logs, generated
`.terraform/` directories, lockfiles, local env, Terraform CLI credential files,
cloud CLI credential directories, keys, and account-specific details must remain
untracked.

## Public Network And Workload Defaults

The network module creates public subnets with public IP assignment enabled and
a default route through an internet gateway. The deployment module creates a
workload security group with outbound access to `0.0.0.0/0` and inbound TCP/80
rules only for CIDRs supplied in `ingress_cidrs`.

The committed examples keep inbound workload access closed. Treat any real
ingress CIDRs, account IDs, backend buckets, and role names as operator-owned
values, not template defaults.

## Change Workflow

For template changes:

1. Update modules and every affected environment root together.
2. Keep `dev`, `staging`, and `prod` input and output contracts aligned unless a
   deliberate environment difference is documented.
3. Update `docs/infra-contract.md` when module inputs, outputs, examples, or
   validation expectations change. New or temporarily unreferenced modules are
   not covered by the default environment-root matrix until they are wired into
   an environment root or added to an explicit `TERRAFORM_ENV_DIRS` check.
4. Review [maintenance.md](maintenance.md) for the right change package and
   validation decision tree.
5. Review [ci.md](ci.md), then run `terraform fmt -check -recursive terraform`
   and `./scripts/validate.sh` before opening a pull request.
