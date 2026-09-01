output "ecr_repository_url" {
  description = "URL of the RONIN ECR repository"
  value       = aws_ecr_repository.ronin.repository_url
}

output "route53_zone_id" {
  description = "Hosted zone ID for ronin.humdaan.co.uk"
  value       = aws_route53_zone.ronin.zone_id
}

output "route53_name_servers" {
  description = "Route 53 nameservers delegated from Cloudflare"
  value       = aws_route53_zone.ronin.name_servers
}
