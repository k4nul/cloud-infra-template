locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "network" {
  source = "../network"

  name_prefix    = local.name_prefix
  vpc_cidr       = var.vpc_cidr
  public_subnets = var.public_subnets
  tags           = local.common_tags
}

module "iam" {
  source = "../iam"

  name_prefix         = local.name_prefix
  trusted_services    = var.trusted_services
  managed_policy_arns = var.managed_policy_arns
  tags                = local.common_tags
}

module "deployment" {
  source = "../deployment"

  name_prefix          = local.name_prefix
  vpc_id               = module.network.vpc_id
  ingress_cidrs        = var.ingress_cidrs
  allow_public_ingress = var.allow_public_ingress
  tags                 = local.common_tags
}
