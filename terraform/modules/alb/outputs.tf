output "security_group_id" {
  description = "Security group ID of the RONIN ALB"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the RONIN ECS target group"
  value       = aws_lb_target_group.ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the RONIN Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the RONIN Application Load Balancer"
  value       = aws_lb.main.zone_id
}