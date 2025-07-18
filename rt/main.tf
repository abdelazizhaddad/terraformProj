resource "aws_route_table" "rt" {
  vpc_id = var.vpc_id

  tags = {
      Name = var.name
    }
}

resource "aws_route" "default" {
  count = var.default_route_gateway_id != null ? 1 : 0

  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.use_internet_gateway ? var.default_route_gateway_id : null
  nat_gateway_id         = var.use_internet_gateway ? null : var.default_route_gateway_id
}

resource "aws_route_table_association" "subnet_associations" {
  for_each       = toset(var.subnet_ids)
  subnet_id      = each.value
  route_table_id = aws_route_table.this.id
}
