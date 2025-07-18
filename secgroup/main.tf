resource "aws_security_group" "secg" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = {
    Name = var.name
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = { for i, rule in var.ingress_rules : i => rule }

  type                     = "ingress"
  from_port               = each.value.from_port
  to_port                 = each.value.to_port
  protocol                = each.value.protocol
  security_group_id       = aws_security_group.secg.id
  cidr_blocks             = lookup(each.value, "cidr_blocks", [])
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
  description             = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "egress" {
  for_each = { for i, rule in var.egress_rules : i => rule }

  type                     = "egress"
  from_port               = each.value.from_port
  to_port                 = each.value.to_port
  protocol                = each.value.protocol
  security_group_id       = aws_security_group.secg.id
  cidr_blocks             = lookup(each.value, "cidr_blocks", [])
  source_security_group_id = lookup(each.value, "source_security_group_id", null)
  description             = lookup(each.value, "description", null)
}
