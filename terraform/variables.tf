variable "aws_region" {
  description = "AWS region used for the main RONIN infrastructure"
  type        = string
  default     = "eu-west-2"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for humdaan.co.uk"
  type        = string
}
