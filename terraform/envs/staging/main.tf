terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "environment" {
  source = "../../modules/environment"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnets       = var.public_subnets
  trusted_services     = var.trusted_services
  managed_policy_arns  = var.managed_policy_arns
  ingress_cidrs        = var.ingress_cidrs
  allow_public_ingress = var.allow_public_ingress
  tags                 = var.tags
}
