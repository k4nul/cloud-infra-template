output "deployment_role_arn" {
  value = aws_iam_role.deployment.arn
}

output "deployment_role_name" {
  value = aws_iam_role.deployment.name
}
