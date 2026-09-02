variable "github_repository_subject" {
  description = "GitHub OIDC subject allowed to assume the RONIN deployment role"
  type        = string
  default     = "repo:rafiquehumdaan-alt@295937241/RONIN@1348616494:ref:refs/heads/main"
}

variable "github_actions_role_name" {
  description = "Name of the IAM role assumed by RONIN GitHub Actions workflows"
  type        = string
  default     = "ronin-github-actions"
}

variable "github_oidc_provider_url" {
  description = "GitHub Actions OIDC issuer URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}
