output "viewer_certificate_arn" {
  description = "ARN of the CloudFront viewer certificate in us-east-1"
  value       = aws_acm_certificate_validation.viewer.certificate_arn
}

output "origin_certificate_arn" {
  description = "ARN of the ALB origin certificate in eu-west-2"
  value       = aws_acm_certificate_validation.origin.certificate_arn
}