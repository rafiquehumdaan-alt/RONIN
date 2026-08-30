provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "RONIN"
      ManagedBy = "Terraform"
    }
  }
}