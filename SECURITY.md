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
- real `.tfvars`
- backend config containing bucket names or credentials
- cloud account IDs, access keys, private keys, or tokens
- production hostnames or internal CIDR maps unless they are intentionally public
