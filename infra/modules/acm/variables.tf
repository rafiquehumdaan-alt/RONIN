variable "domain_name" {
  description = "Public domain name for RONIN"
  type        = string
}

variable "origin_domain_name" {
  description = "Origin domain name used by CloudFront to reach the ALB"
  type        = string
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID for ronin.humdaan.co.uk"
  type        = string
}