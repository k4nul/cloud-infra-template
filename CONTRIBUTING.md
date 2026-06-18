# Contributing to Cloud Infrastructure Template

This project is a reusable AWS Terraform template. Keep changes provider-neutral
where practical within the AWS provider scope and avoid organization-specific
network, IAM, account, or backend assumptions.

## Local Setup

```bash
./scripts/validate.sh
```

`./scripts/validate.sh` runs `terraform init -backend=false` and
`terraform validate` for the checked-in environment roots. It also checks the
tracked file list for public-safety violations such as generated `.terraform/`
directories, provider lockfiles, state, plans, real `.tfvars`, local env,
Terraform CLI credential files, cloud CLI credential directories, crash logs,
private keys, TFLint plugin cache directories, and backend config under
`config/*.hcl` beyond `config/backend.hcl.example`.
Keep `TERRAFORM_ENABLE_TFLINT=1` and `TERRAFORM_ENABLE_CHECKOV=1` as optional
local scans so public CI continues to run without repository secrets, provider
lint plugins, or extra credentials.
See [docs/testing.md](docs/testing.md) for CI parity details and
[docs/troubleshooting.md](docs/troubleshooting.md) for common validation
failures.

## Pull Request Checklist

- Do not commit `.terraform/`, `.terraform.lock.hcl`, `.tflint.d/`, state
  files, real `.tfvars`, plans, crash logs, local env, Terraform CLI credential
  files, cloud CLI credential directories, keys, or real backend config under
  `config/*.hcl`.
- Do not narrow pull-request CI path filters in a way that lets public-safety checks be skipped.
- Keep real account IDs, domains, regions, and role names out of examples.
- Keep example ingress closed by default unless the change intentionally documents a safe CIDR and the `allow_public_ingress` opt-in.
- Keep public pull-request CI backend-disabled and free of repository secrets.
- Update `docs/infra-contract.md` when module contracts change.
- Update [docs/onboarding.md](docs/onboarding.md) or [docs/testing.md](docs/testing.md)
  when first-run, customization, or validation behavior changes.
- Keep `terraform.tfvars.example` files safe to publish.

## Terraform Style

Prefer module inputs for reusable behavior and environment roots for override
values. Keep destructive operations outside documentation examples unless they
are explicitly marked as operator-controlled.
