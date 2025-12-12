# ============================================
# ECSモジュール用出力値定義ファイル
# ============================================

output "alb_dns_name" {
  description = "ALBのDNS名（アプリケーションへのアクセスURL）"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALBのZone ID（Route 53設定に使用）"
  value       = aws_lb.main.zone_id
}

output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECSサービス名"
  value       = aws_ecs_service.main.name
}

output "ecs_task_definition_arn" {
  description = "ECS Task DefinitionのARN"
  value       = aws_ecs_task_definition.app.arn
}

output "ecs_security_group_id" {
  description = "ECSタスク用セキュリティグループID"
  value       = aws_security_group.ecs.id
}

output "alb_security_group_id" {
  description = "ALB用セキュリティグループID"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target GroupのARN"
  value       = aws_lb_target_group.main.arn
}

