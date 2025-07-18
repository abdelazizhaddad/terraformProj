variable "name" {
  description = "Name tag for the route table"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}


variable "default_route_gateway_id" {
  description = "ID of the gateway to use for 0.0.0.0/0 route"
  type        = string
  default     = null
}

variable "use_internet_gateway" {
  description = "True if using an Internet Gateway (false = NAT Gateway)"
  type        = bool
  default     = true
}
