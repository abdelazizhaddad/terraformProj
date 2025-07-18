output "subnet_id" {
  value = aws_subnet.this.id
}
output "subnet_cidr_block" {
  description = "The CIDR block of the subnet"
  value       = aws_subnet.subnet_a.cidr_block
}

output "subnet_az" {
  description = "The Availability Zone of the subnet"
  value       = aws_subnet.subnet_a.availability_zone
}