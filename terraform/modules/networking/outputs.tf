# ============================================
# Networking Module - 出力値定義
# ============================================
#
# このファイルの役割:
# - Networkingモジュールで作成したリソースの情報を外部に公開
# - 他のモジュール（database、ecs）から参照される

# ============================================
# VPC関連の出力
# ============================================

output "vpc_id" {
  description = "作成されたVPCのID"
  value       = aws_vpc.main.id
  
  # 使用例: 他のモジュールでセキュリティグループを作成する際に必要
}

output "vpc_cidr_block" {
  description = "VPCのCIDRブロック"
  value       = aws_vpc.main.cidr_block
  
  # 使用例: セキュリティグループのルールで「VPC内からのアクセスを許可」する際に使用
}

# ============================================
# サブネット関連の出力
# ============================================

output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = aws_subnet.public[*].id
  
  # [*] の意味: すべての要素のidを配列として取得
  # 例: ["subnet-abc123", "subnet-def456"]
  #
  # 使用例: ALB（Application Load Balancer）の配置先として使用
}

output "private_subnet_ids" {
  description = "プライベートサブネットのIDリスト"
  value       = aws_subnet.private[*].id
  
  # 使用例: ECSタスク（アプリケーションコンテナ）の配置先として使用
}

output "database_subnet_ids" {
  description = "データベースサブネットのIDリスト"
  value       = aws_subnet.database[*].id
  
  # 使用例: RDSインスタンスの配置先として使用
}

# ============================================
# ゲートウェイ関連の出力
# ============================================

output "internet_gateway_id" {
  description = "インターネットゲートウェイのID"
  value       = aws_internet_gateway.main.id
  
  # 通常は直接参照しないが、デバッグ時に有用
}

output "nat_gateway_id" {
  description = "NATゲートウェイのID"
  value       = aws_nat_gateway.main.id
  
  # 通常は直接参照しないが、デバッグ時に有用
}

# ============================================
# ルートテーブル関連の出力
# ============================================

output "public_route_table_id" {
  description = "パブリックルートテーブルのID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "プライベートルートテーブルのID"
  value       = aws_route_table.private.id
}

output "database_route_table_id" {
  description = "データベースルートテーブルのID"
  value       = aws_route_table.database.id
}

# ============================================
# 参考: 出力値の使い方
# ============================================
# 
# 他のモジュールから参照する例:
# 
# module "database" {
#   source = "./modules/database"
#   
#   vpc_id     = module.networking.vpc_id
#   subnet_ids = module.networking.database_subnet_ids
# }
#
# この出力値により、モジュール間の連携が可能になる

