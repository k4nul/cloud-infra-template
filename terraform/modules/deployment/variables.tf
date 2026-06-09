variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ingress_cidrs" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
