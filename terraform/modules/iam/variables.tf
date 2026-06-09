variable "name_prefix" {
  type = string
}

variable "trusted_services" {
  type    = list(string)
  default = ["ec2.amazonaws.com"]
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
