variable "domain_name" {
  description = "Public domain name for RONIN"
  type        = string
}

variable "origin_domain_name" {
  description = "Domain name CloudFront uses to reach the ALB"
  type        = string
}

variable "viewer_certificate_arn" {
  description = "ARN of the ACM certificate for CloudFront"
  type        = string
}