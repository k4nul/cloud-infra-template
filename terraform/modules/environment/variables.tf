variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "trusted_services" {
  type = list(string)
}

variable "managed_policy_arns" {
  type = list(string)
}

variable "ingress_cidrs" {
  type = list(string)

  validation {
    condition     = alltrue([for cidr in var.ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "Each ingress_cidrs value must be a valid IPv4 CIDR block."
  }
}

variable "allow_public_ingress" {
  type = bool
}

variable "tags" {
  type = map(string)
}
