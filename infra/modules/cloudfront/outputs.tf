output "distribution_id" {
  description = "ID of the RONIN CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "hosted_zone_id" {
  description = "CloudFront Route 53 hosted zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}