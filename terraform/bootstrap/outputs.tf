output "terraform_state_bucket" {
  description = "S3 bucket used for RONIN Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by RONIN GitHub Actions workflows"
  value       = aws_iam_role.github_actions.arn
}
