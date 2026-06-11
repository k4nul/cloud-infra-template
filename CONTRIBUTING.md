# Contributing to Cloud Infrastructure Template

This project is a reusable Terraform template. Keep changes provider-neutral
where practical and avoid organization-specific network, IAM, account, or
backend assumptions.

## Local Setup

```bash
terraform fmt -check -recursive terraform
./scripts/validate.sh
```

`./scripts/validate.sh` runs `terraform init -backend=false` and
`terraform validate` for the checked-in environment roots.

## Pull Request Checklist

- Do not commit `.terraform/`, state files, real `.tfvars`, plans, keys, or backend config.
- Keep real account IDs, domains, regions, and role names out of examples.
- Keep example ingress closed by default unless the change intentionally documents a safe CIDR and the `allow_public_ingress` opt-in.
- Keep public pull-request CI backend-disabled and free of repository secrets.
- Update `docs/infra-contract.md` when module contracts change.
- Keep `terraform.tfvars.example` files safe to publish.

## Terraform Style

Prefer module inputs for reusable behavior and environment roots for override
values. Keep destructive operations outside documentation examples unless they
are explicitly marked as operator-controlled.
