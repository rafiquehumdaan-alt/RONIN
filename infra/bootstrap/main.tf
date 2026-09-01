resource "aws_s3_bucket" "terraform_state" {
  bucket        = "ronin-terraform-state-435059220418"
  force_destroy = true

  tags = {
    Name    = "ronin-terraform-state"
    Project = "RONIN"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
  for_each = toset(aws_route53_zone.ronin.name_servers)

  zone_id = var.cloudflare_zone_id
  name    = "ronin"
  type    = "NS"
  content = each.value
  ttl     = 3600
}