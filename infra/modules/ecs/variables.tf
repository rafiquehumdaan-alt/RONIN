variable "vpc_id" {
  description = "ID of the RONIN VPC"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID of the RONIN ALB"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the RONIN ECR repository"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the RONIN ECS task role"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the RONIN DynamoDB table"
  type        = string
}

variable "reports_bucket_name" {
  description = "Name of the RONIN reports S3 bucket"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for the RONIN ECS tasks"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}