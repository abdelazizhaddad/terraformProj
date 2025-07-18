#the subnet module 

resource "aws_subnet" "subnet_a" {
  cidr_block              = var.cidr_sub
  vpc_id                  = aws_vpc.vpc_id.id
  availability_zone       = var.az
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = var.name
  }
}