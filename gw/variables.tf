variable "name" {
  description = "Name tag for the Internet Gateway"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID where the Internet Gateway will be created"
  type        = string
}