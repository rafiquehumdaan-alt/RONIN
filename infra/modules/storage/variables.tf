variable "dynamodb_table_name" {
  description = "Name of the DynamoDB analyses table"
  type        = string
}

variable "reports_bucket_name" {
  description = "Name of the S3 reports bucket"
  type        = string
}