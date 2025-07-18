
variable "cidr_sub" {
  description = "Subnet CIDR block"
  type = string
}
variable "vpc_id" {
  description = "The CIDR block for the subnet"
  type = string
}
variable "az" {
  description = "The availability zone for the subnet"
  type = string
}
variable "map_public_ip_on_launch" {
  description = "Assign a public IP to instances (public or private sub)"
  type        = bool
  default     = false
}
variable "name" {
  description = "Name of the subnet"
  type = string
}