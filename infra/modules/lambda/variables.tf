variable "dynamodb_table_name" {
  description = "Name of the RONIN DynamoDB analyses table"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of the RONIN DynamoDB analyses table"
  type        = string
}

variable "reports_bucket_name" {
  description = "Name of the RONIN reports S3 bucket"
  type        = string
}

variable "reports_bucket_arn" {
  description = "ARN of the RONIN reports S3 bucket"
  type        = string
}