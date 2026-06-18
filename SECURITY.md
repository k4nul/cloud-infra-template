# Security Policy

## Supported Versions

Security fixes target the current `main` branch until versioned releases are
published.

## Reporting a Vulnerability

Use GitHub private vulnerability reporting if it is enabled for the repository.
If it is not available, open a public issue with a short summary only and ask
for a private disclosure channel. Do not include exploit steps, account IDs,
state data, credentials, or real infrastructure details in a public issue.

## Infrastructure Data Safety

Never commit:

- Terraform state or plan files
- generated `.terraform/` directories, provider lockfiles, or TFLint plugin
  cache directories
- real `.tfvars`
- local env files, Terraform CLI credentials, cloud CLI credential directories,
  or crash logs
- real backend config under `config/*.hcl`; only `config/backend.hcl.example`
  belongs in the public template
- cloud account IDs, access keys, private keys, or tokens
- production hostnames or internal CIDR maps unless they are intentionally public
