# Cloud Infrastructure Contract

- Network module: creates the VPC, public subnets, internet gateway, and route table baseline
- IAM module: creates a deployment role with parameterized trust and managed policies
- Deployment module: creates a workload security group for downstream compute or cluster modules
- Environment roots: keep environment-specific CIDR, region, names, and tags outside reusable modules
- State: configure remote state through backend config, not committed secrets or local state files
