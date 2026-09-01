output "terraform_state_bucket" {
  value = aws_s3_bucket.terraform_state.id
}

output "route53_zone_id" {
  value = aws_route53_zone.ronin.zone_id
}

output "route53_name_servers" {
  value = aws_route53_zone.ronin.name_servers
}

output "ecr_repository_url" {
  value = aws_ecr_repository.ronin.repository_url
}