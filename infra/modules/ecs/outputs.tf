output "cluster_id" {
  description = "ID of the RONIN ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the RONIN ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "Name of the RONIN ECS service"
  value       = aws_ecs_service.app.name
}

output "security_group_id" {
  description = "Security group ID of the RONIN ECS tasks"
  value       = aws_security_group.ecs.id
}