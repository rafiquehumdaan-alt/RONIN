variable "vpc_cidr" {
  description = "CIDR block for the RONIN VPC"
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for public subnet A"
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for public subnet B"
  type        = string
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for private application subnet A"
  type        = string
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for private application subnet B"
  type        = string
}

variable "availability_zone_a" {
  description = "First availability zone"
  type        = string
}

variable "availability_zone_b" {
  description = "Second availability zone"
  type        = string
}