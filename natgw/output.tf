output "nat_gateway_id" {
  value = aws_nat_gateway.ngw.id
}

output "eip" {
  value = aws_eip.ngw.public_ip
}
