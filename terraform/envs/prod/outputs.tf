output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "deployment_role_arn" {
  value = module.iam.deployment_role_arn
}

output "workload_security_group_id" {
  value = module.deployment.workload_security_group_id
}
