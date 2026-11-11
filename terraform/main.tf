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

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }
}

resource "aws_ecr_repository" "ronin" {
  name                 = "ronin"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "ronin"
    Project = "RONIN"
  }
}

resource "aws_route53_zone" "ronin" {
  name = "ronin.humdaan.co.uk"

  tags = {
    Name    = "ronin.humdaan.co.uk"
    Project = "RONIN"
  }
}

resource "cloudflare_dns_record" "ronin_delegation" {
  for_each = {
    ns1 = aws_route53_zone.ronin.name_servers[0]
    ns2 = aws_route53_zone.ronin.name_servers[1]
    ns3 = aws_route53_zone.ronin.name_servers[2]
    ns4 = aws_route53_zone.ronin.name_servers[3]
  }

  zone_id = var.cloudflare_zone_id
  name    = "ronin"
  type    = "NS"
  content = each.value
  ttl     = 3600
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_a_cidr  = "10.0.1.0/24"
  public_subnet_b_cidr  = "10.0.2.0/24"
  private_subnet_a_cidr = "10.0.11.0/24"
  private_subnet_b_cidr = "10.0.12.0/24"

  availability_zone_a = "eu-west-2a"
  availability_zone_b = "eu-west-2b"
}

module "storage" {
  source = "./modules/storage"

  dynamodb_table_name = "ronin-analyses"
  reports_bucket_name = "ronin-reports"
}

module "iam" {
  source = "./modules/iam"

  dynamodb_table_arn = module.storage.dynamodb_table_arn
  reports_bucket_arn = module.storage.reports_bucket_arn
}

module "acm" {
  source = "./modules/acm"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name        = "ronin.humdaan.co.uk"
  origin_domain_name = "origin.ronin.humdaan.co.uk"
  route53_zone_id    = aws_route53_zone.ronin.zone_id

  depends_on = [cloudflare_dns_record.ronin_delegation]
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.origin_certificate_arn
}

module "cloudfront" {
  source = "./modules/cloudfront"

  domain_name            = "ronin.humdaan.co.uk"
  origin_domain_name     = "origin.ronin.humdaan.co.uk"
  viewer_certificate_arn = module.acm.viewer_certificate_arn
}

module "route53" {
  source = "./modules/route53"

  zone_id                = aws_route53_zone.ronin.zone_id
  domain_name            = "ronin.humdaan.co.uk"
  origin_domain_name     = "origin.ronin.humdaan.co.uk"
  alb_dns_name           = module.alb.alb_dns_name
  alb_zone_id            = module.alb.alb_zone_id
  cloudfront_domain_name = module.cloudfront.domain_name
  cloudfront_zone_id     = module.cloudfront.hosted_zone_id
}

module "ecs" {
  source = "./modules/ecs"

  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  ecr_repository_url = aws_ecr_repository.ronin.repository_url

  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn      = module.iam.ecs_task_role_arn

  dynamodb_table_name = module.storage.dynamodb_table_name
  reports_bucket_name = module.storage.reports_bucket_name
}

module "lambda" {
  source = "./modules/lambda"

  dynamodb_table_name = module.storage.dynamodb_table_name
  dynamodb_table_arn  = module.storage.dynamodb_table_arn

  reports_bucket_name = module.storage.reports_bucket_name
  reports_bucket_arn  = module.storage.reports_bucket_arn
}
