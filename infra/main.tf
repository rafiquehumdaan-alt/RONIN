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
}