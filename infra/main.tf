data "aws_route53_zone" "ronin" {
  name         = "ronin.humdaan.co.uk"
  private_zone = false
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

module "ecr" {
  source = "./modules/ecr"

  repository_name = "ronin"
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

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.origin_certificate_arn
}

module "ecs" {
  source = "./modules/ecs"

  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  ecr_repository_url = module.ecr.repository_url
  image_tag          = "v3"

  ecs_execution_role_arn = module.iam.ecs_execution_role_arn
  ecs_task_role_arn      = module.iam.ecs_task_role_arn

  dynamodb_table_name = module.storage.dynamodb_table_name
  reports_bucket_name = module.storage.reports_bucket_name
}

module "acm" {
  source = "./modules/acm"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name        = "ronin.humdaan.co.uk"
  origin_domain_name = "origin.ronin.humdaan.co.uk"
  route53_zone_id    = data.aws_route53_zone.ronin.zone_id
}

module "route53" {
  source = "./modules/route53"

  zone_id            = data.aws_route53_zone.ronin.zone_id
  origin_domain_name = "origin.ronin.humdaan.co.uk"

  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id

  cloudfront_domain_name = module.cloudfront.domain_name
  cloudfront_zone_id     = module.cloudfront.hosted_zone_id
}

module "cloudfront" {
  source = "./modules/cloudfront"

  domain_name            = "ronin.humdaan.co.uk"
  origin_domain_name     = "origin.ronin.humdaan.co.uk"
  viewer_certificate_arn = module.acm.viewer_certificate_arn
}

module "lambda" {
  source = "./modules/lambda"

  dynamodb_table_name = module.storage.dynamodb_table_name
  dynamodb_table_arn  = module.storage.dynamodb_table_arn

  reports_bucket_name = module.storage.reports_bucket_name
  reports_bucket_arn  = module.storage.reports_bucket_arn
}