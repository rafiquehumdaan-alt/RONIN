variable "dynamodb_table_arn" {
  description = "ARN of the RONIN DynamoDB table"
  type        = string
}

variable "reports_bucket_arn" {
  description = "ARN of the RONIN reports S3 bucket"
  type        = string
}