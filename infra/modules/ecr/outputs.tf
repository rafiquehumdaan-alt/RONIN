output "repository_url" {
  description = "URL of the RONIN ECR repository"
  value       = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  description = "ARN of the RONIN ECR repository"
  value       = aws_ecr_repository.main.arn
}