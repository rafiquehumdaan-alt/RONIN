terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "ronin-terraform-state-435059220418"
    key          = "ronin/foundation.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
