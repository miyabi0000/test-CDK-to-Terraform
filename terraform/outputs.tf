# ============================================
# 出力値定義ファイル
# ============================================
#
# このファイルの役割:
# - terraform apply 実行後に表示する情報を定義
# - 他のTerraformモジュールから参照できる値を公開
# - 重要な情報（URL、エンドポイント等）をユーザーに提示
#
# 出力値の使い方:
# - terraform output で確認
# - terraform output -json で JSON形式で取得
# - CI/CDパイプラインで自動的に値を取得

# ============================================
# ネットワーク関連の出力
# ============================================

output "vpc_id" {
  description = "作成されたVPCのID"
  value       = try(module.networking.vpc_id, null)
  
  # tryの意味:
  # - module.networkingが存在しない場合、エラーではなくnullを返す
  # - 段階的な構築時にエラーを防ぐ
}

output "vpc_cidr_block" {
  description = "VPCのCIDRブロック（IPアドレス範囲）"
  value       = try(module.networking.vpc_cidr_block, null)
}

output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = try(module.networking.public_subnet_ids, [])
  
  # ALBの配置先として使用
}

output "private_subnet_ids" {
  description = "プライベートサブネットのIDリスト"
  value       = try(module.networking.private_subnet_ids, [])
  
  # ECSタスクの配置先として使用
}

output "database_subnet_ids" {
  description = "データベースサブネットのIDリスト"
  value       = try(module.networking.database_subnet_ids, [])
  
  # RDSインスタンスの配置先として使用
}

# ============================================
# データベース関連の出力
# ============================================

output "database_endpoint" {
  description = "RDSデータベースのエンドポイント（接続先アドレス）"
  value       = try(module.database.db_instance_endpoint, null)
  
  # 形式: hostname:port
  # 例: saa-learning-db.xxxxxxxxxx.ap-northeast-1.rds.amazonaws.com:5432
}

output "database_name" {
  description = "データベース名"
  value       = var.database_name
}

output "database_secret_arn" {
  description = "データベース認証情報が保存されているSecrets ManagerのARN"
  value       = try(module.database.db_secret_arn, null)
  sensitive   = true  # terraform output では表示されない（セキュリティ）
  
  # ARN (Amazon Resource Name):
  # - AWSリソースを一意に識別するID
  # - 例: arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:db-password
}

# ============================================
# コンテナ関連の出力
# ============================================

output "ecr_repository_url" {
  description = "ECRリポジトリのURL（Dockerイメージのプッシュ先）"
  value       = try(module.ecs.ecr_repository_url, null)
  
  # 使用方法:
  # docker tag my-app:latest <この値>:latest
  # docker push <この値>:latest
}

output "ecs_cluster_name" {
  description = "ECSクラスター名"
  value       = try(module.ecs.ecs_cluster_name, null)
}

output "ecs_service_name" {
  description = "ECSサービス名"
  value       = try(module.ecs.ecs_service_name, null)
}

# ============================================
# ロードバランサー関連の出力
# ============================================

output "load_balancer_dns_name" {
  description = "Application Load BalancerのDNS名（アプリケーションのアクセスURL）"
  value       = try(module.ecs.alb_dns_name, null)
  
  # このURLにブラウザでアクセスすると、アプリケーションが表示される
  # 例: saa-learning-alb-1234567890.ap-northeast-1.elb.amazonaws.com
}

output "load_balancer_zone_id" {
  description = "ALBのRoute53ホストゾーンID"
  value       = try(module.ecs.alb_zone_id, null)
  
  # Route53でカスタムドメインを設定する際に使用
}

# ============================================
# アクセス情報のまとめ
# ============================================

output "application_url" {
  description = "🚀 アプリケーションにアクセスするURL"
  value       = try("http://${module.ecs.alb_dns_name}", "ALBがまだ作成されていません")
  
  # ユーザーフレンドリーな出力
  # terraform apply 後、このURLでアプリケーションにアクセス可能
}

output "next_steps" {
  description = "📋 次のステップ"
  value = <<-EOT
  
  ✅ Terraform apply が完了しました！
  
  次のステップ:
  
  1. アプリケーションにアクセス:
     ${try("http://${module.ecs.alb_dns_name}", "ALBがまだ作成されていません")}
  
  2. Dockerイメージをプッシュ:
     docker tag your-app:latest ${try(module.ecs.ecr_repository_url, "ECRがまだ作成されていません")}:latest
     docker push ${try(module.ecs.ecr_repository_url, "ECRがまだ作成されていません")}:latest
  
  3. ECSサービスを更新:
     aws ecs update-service --cluster ${try(module.ecs.ecs_cluster_name, "クラスターがまだ作成されていません")} \
       --service ${try(module.ecs.ecs_service_name, "サービスがまだ作成されていません")} \
       --force-new-deployment
  
  4. ログを確認:
     aws logs tail /ecs/saa-learning --follow
  
  EOT
}

