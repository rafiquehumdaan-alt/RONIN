output "terraform_state_bucket" {
  description = "S3 bucket used for the main Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "ecr_repository_url" {
  description = "URL of the RONIN ECR repository"
  value       = aws_ecr_repository.ronin.repository_url
}

output "route53_zone_id" {
  description = "Hosted zone ID for ronin.humdaan.co.uk"
  value       = aws_route53_zone.ronin.zone_id
}

output "route53_name_servers" {
  description = "Route 53 nameservers to delegate from Cloudflare"
  value       = aws_route53_zone.ronin.name_servers
}