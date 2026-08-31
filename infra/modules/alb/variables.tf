variable "vpc_id" {
  description = "ID of the RONIN VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets for the ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate used by the ALB HTTPS listener"
  type        = string
}