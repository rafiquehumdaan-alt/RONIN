resource "aws_route53_record" "origin" {
  zone_id = var.zone_id
  name    = var.origin_domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Creates a Route 53 A alias record that points the origin domain to the Application Load Balancer.

resource "aws_route53_record" "app" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# Creates a Route 53 A alias record that points the public RONIN domain to the CloudFront distribution.