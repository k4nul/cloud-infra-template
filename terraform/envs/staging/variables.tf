variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "platform"
}

variable "environment" {
  type    = string
  default = "staging"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {
    public_a = {
      cidr_block        = "10.20.1.0/24"
      availability_zone = "us-east-1a"
    }
    public_b = {
      cidr_block        = "10.20.2.0/24"
      availability_zone = "us-east-1b"
    }
  }
}

variable "trusted_services" {
  type    = list(string)
  default = ["ec2.amazonaws.com"]
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "ingress_cidrs" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
