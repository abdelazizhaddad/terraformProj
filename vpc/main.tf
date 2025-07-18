resource "aws_vpc" "this" {
  cidr_block = var.cidr_vpc
  tags = {
    Name = var.name
  }
}
