# ============================================
# Database Module - 出力値
# ============================================

output "db_instance_id" {
  description = "RDSインスタンスID"
  value       = aws_db_instance.main.id
}

output "db_endpoint" {
  description = "データベースエンドポイント"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "データベースホスト名"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "データベースポート"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "データベース名"
  value       = aws_db_instance.main.db_name
}

output "db_security_group_id" {
  description = "データベースセキュリティグループID"
  value       = aws_security_group.database.id
}

output "secret_arn" {
  description = "Secrets Manager ARN"
  value       = aws_secretsmanager_secret.database.arn
}

output "secret_name" {
  description = "Secrets Manager 名前"
  value       = aws_secretsmanager_secret.database.name
}


