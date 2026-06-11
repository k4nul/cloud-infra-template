resource "aws_security_group" "workload" {
  name        = "${var.name_prefix}-workload"
  description = "Template workload security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = toset(var.ingress_cidrs)

    content {
      description = "HTTP from allowed CIDR"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    precondition {
      condition     = var.allow_public_ingress || !contains(var.ingress_cidrs, "0.0.0.0/0")
      error_message = "Set allow_public_ingress to true before allowing 0.0.0.0/0 workload ingress."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-workload"
  })
}
