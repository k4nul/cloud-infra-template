## Summary

Describe the infrastructure template change and affected modules or environment roots.

## Validation

List the commands you ran, or explain why a command was not applicable.

## Checklist

- [ ] `./scripts/validate.sh` was run, or the reason it was not run is documented.
- [ ] `./scripts/validate-ci-workflow.sh` was run when CI workflow behavior changed.
- [ ] `./tests/validate_public_safety_test.sh` was run when validation script or CI behavior changed.
- [ ] No state, plans, credentials, or real `.tfvars` are committed.
- [ ] Examples remain safe for a public repository.
- [ ] Module contracts or docs are updated when inputs/outputs change.
