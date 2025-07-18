resource "aws_vpc" "main" {
  cidr_block = var.cidr_vpc
  
  tags = {
    Name = var.name
  }
}