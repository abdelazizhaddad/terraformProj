resource "aws_eip" "ngw" {
  domain = "vpc"
  tags = {
    Name = "${var.name}-eip"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.this.id
  subnet_id     = var.public_subnet_id
  tags = {
    Name = var.name
  }
}