output "vpc_id" {
  value = module.environment.vpc_id
}

output "public_subnet_ids" {
  value = module.environment.public_subnet_ids
}

output "deployment_role_arn" {
  value = module.environment.deployment_role_arn
}

output "workload_security_group_id" {
  value = module.environment.workload_security_group_id
}
