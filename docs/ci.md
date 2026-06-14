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
and configuration-only changes still run the public-safety file check in
`./scripts/validate.sh`, which prevents accidental commits of local Terraform
artifacts or operator-owned secrets.

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
```

Checkov is disabled in public CI so the required lane has no extra policy
scanner dependency. Run the optional local policy scan with
`TERRAFORM_ENABLE_CHECKOV=1 ./scripts/validate.sh` when Checkov is installed.

## Validation Command

CI runs exactly:

```bash
./scripts/validate.sh
```

That script:

1. rejects tracked Terraform state, plans, real `.tfvars`, private key material,
   generated `.terraform/` directories, lockfiles, and real backend config under
   `config/*.hcl`,
2. runs `terraform fmt -check -recursive terraform`,
3. initializes each selected environment root with `terraform init
   -backend=false -input=false -no-color`,
4. runs `terraform validate -no-color` for each selected environment root,
5. skips Checkov unless `TERRAFORM_ENABLE_CHECKOV=1` is set.

The default environment matrix is:

```text
terraform/envs/dev terraform/envs/staging terraform/envs/prod
```

## Pull-Request Expectations

Before requesting review:

- run `./scripts/validate.sh` locally, or explain the exact blocker in the pull
  request validation section,
- keep only public examples committed, such as `terraform.tfvars.example` and
  `config/backend.hcl.example`,
- keep real `.tfvars`, backend config, state, plans, provider lockfiles,
  generated Terraform directories, keys, and account-specific values untracked,
- update `docs/infra-contract.md` when module inputs, outputs, examples,
  validation behavior, or environment-root wiring changes.

If CI fails, start with [troubleshooting.md](troubleshooting.md). The most common
public CI failures are missing formatting, an accidentally tracked local
Terraform artifact, or a change that updates one environment root without
keeping the shared root contract aligned.
