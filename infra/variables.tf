variable "aws_region" {
  description = "AWS region used for the main RONIN infrastructure"
  type        = string
  default     = "eu-west-2"
}

variable "image_tag" {
  description = "Docker image tag to deploy to ECS"
  type        = string
  default     = "v3"
}