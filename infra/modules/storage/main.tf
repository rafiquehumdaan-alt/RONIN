resource "aws_dynamodb_table" "analyses" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "analysis_id"

  attribute {
    name = "analysis_id"
    type = "S"
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}

resource "aws_s3_bucket" "reports" {
  bucket        = var.reports_bucket_name
  force_destroy = true

  tags = {
    Name = var.reports_bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Blocks all public access to the RONIN reports S3 bucket to keep stored reports private.