variable "zone_id" {
  description = "ID of the RONIN Route 53 hosted zone"
  type        = string
}

variable "domain_name" {
  description = "Public domain name for RONIN"
  type        = string
}

variable "origin_domain_name" {
  description = "Domain name used by CloudFront to reach the ALB"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the RONIN Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Route 53 zone ID of the RONIN Application Load Balancer"
  type        = string
}

variable "cloudfront_domain_name" {
  description = "Domain name of the RONIN CloudFront distribution"
  type        = string
}

variable "cloudfront_zone_id" {
  description = "Route 53 hosted zone ID of the CloudFront distribution"
  type        = string
}