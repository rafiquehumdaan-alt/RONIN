resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  is_ipv6_enabled = false
  comment         = "RONIN CloudFront distribution"

  aliases = [var.domain_name]

  origin {
    domain_name = var.origin_domain_name
    origin_id   = "ronin-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "ronin-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  # Redirects users to HTTPS, forwards requests to the ALB, allows all common HTTP methods, and only caches GET/HEAD requests using the configured AWS policies.

  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "ronin-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # Applies a dedicated CloudFront caching rule to /static/* files, allowing only GET/HEAD requests and caching them at CloudFront edge locations for faster delivery.

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.viewer_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "ronin-cloudfront"
  }
}

# Allows CloudFront access from all geographic locations, uses SNI and requires clients to use TLS 1.2 or newer for HTTPS connections.