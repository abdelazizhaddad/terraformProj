variable "name" {
  type        = string
  description = "Name tag for the NAT Gateway"
}

variable "public_subnet_id" {
  type        = string
  description = "Subnet ID for the NAT Gateway (must be public)"
}
