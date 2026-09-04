terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_acm_certificate" "viewer" {
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ronin-cloudfront-certificate"
  }
}

# Creates a DNS-validated ACM certificate in us-east-1 for the CloudFront domain.
# Ensures a replacement certificate is created before the existing one is destroyed.

resource "aws_acm_certificate" "origin" {
  domain_name       = var.origin_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ronin-origin-certificate"
  }
}

# Creates a DNS-validated ACM certificate for the origin domain used by the ALB.
# Creates any replacement certificate before removing the existing one.

resource "aws_route53_record" "viewer_validation" {
  for_each = {
    for dvo in aws_acm_certificate.viewer.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Creates the Route 53 DNS records required by ACM to prove ownership of the viewer domain.
# Uses ACM's validation details to automatically create the correct records.

resource "aws_route53_record" "origin_validation" {
  for_each = {
    for dvo in aws_acm_certificate.origin.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Creates the Route 53 DNS records required by ACM to prove ownership of the origin domain.
# Uses ACM's validation details to automatically create the correct records.

resource "aws_acm_certificate_validation" "viewer" {
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.viewer.arn

  validation_record_fqdns = [
    for record in aws_route53_record.viewer_validation :
    record.fqdn
  ]
}

# Completes ACM validation of the CloudFront viewer certificate using the Route 53 DNS records.
# Ensures the certificate is validated and ready for use.

resource "aws_acm_certificate_validation" "origin" {
  certificate_arn = aws_acm_certificate.origin.arn

  validation_record_fqdns = [
    for record in aws_route53_record.origin_validation :
    record.fqdn
  ]
}

# Completes ACM validation of the origin certificate using the Route 53 DNS records.
# Ensures the certificate is validated and ready for use by the ALB.