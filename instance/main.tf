resource "aws_instance" "ec2" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  security_groups             = var.security_group_id
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  
  tags = {
    Name = var.name
  }
}