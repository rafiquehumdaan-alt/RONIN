output "dynamodb_table_arn" {
  value = aws_dynamodb_table.analyses.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.analyses.name
}

output "reports_bucket_arn" {
  value = aws_s3_bucket.reports.arn
}

output "reports_bucket_name" {
  value = aws_s3_bucket.reports.bucket
}