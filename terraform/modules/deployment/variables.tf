variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "allow_public_ingress" {
  type    = bool
  default = false
}

variable "ingress_cidrs" {
  type    = list(string)
  default = []

  validation {
    condition     = alltrue([for cidr in var.ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "Each ingress_cidrs value must be a valid IPv4 CIDR block."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
