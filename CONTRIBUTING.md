# Contributing to Cloud Infrastructure Template

This project is a reusable Terraform template. Keep changes provider-neutral
where practical and avoid organization-specific network, IAM, account, or
backend assumptions.

## Local Setup

```bash
./scripts/validate.sh
```

`./scripts/validate.sh` runs `terraform init -backend=false` and
`terraform validate` for the checked-in environment roots. It also checks the
tracked file list for public-safety violations such as state, plans, real
`.tfvars`, private keys, and backend config beyond `config/backend.hcl.example`.
Keep `TERRAFORM_ENABLE_CHECKOV=1` as an optional local policy scan so public CI
continues to run without repository secrets or extra credentials.

## Pull Request Checklist

- Do not commit `.terraform/`, state files, real `.tfvars`, plans, keys, or backend config.
- Do not narrow pull-request CI path filters in a way that lets public-safety checks be skipped.
- Keep real account IDs, domains, regions, and role names out of examples.
- Keep example ingress closed by default unless the change intentionally documents a safe CIDR and the `allow_public_ingress` opt-in.
- Keep public pull-request CI backend-disabled and free of repository secrets.
- Update `docs/infra-contract.md` when module contracts change.
- Keep `terraform.tfvars.example` files safe to publish.

## Terraform Style

Prefer module inputs for reusable behavior and environment roots for override
values. Keep destructive operations outside documentation examples unless they
are explicitly marked as operator-controlled.
