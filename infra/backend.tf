terraform {
  backend "s3" {
    bucket       = "ronin-terraform-state-435059220418"
    key          = "ronin/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}