# ============================================
# ECSモジュール用変数定義ファイル
# ============================================

# ============================================
# 基本設定
# ============================================
variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスに使用）"
  type        = string
}

variable "environment" {
  description = "環境名（開発/ステージング/本番を区別）"
  type        = string
}

# ============================================
# ネットワーク設定
# ============================================
variable "vpc_id" {
  description = "ECSとALBを配置するVPCのID"
  type        = string
}

variable "public_subnet_ids" {
  description = "ALBを配置するパブリックサブネットのIDリスト"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "ECSタスクを配置するプライベートサブネットのIDリスト"
  type        = list(string)
}

# ============================================
# ECR設定
# ============================================
variable "ecr_repository_url" {
  description = "ECRリポジトリのURL（Dockerイメージの取得元）"
  type        = string
}

# ============================================
# データベース設定
# ============================================
variable "database_endpoint" {
  description = "RDSデータベースのエンドポイト"
  type        = string
}

variable "database_name" {
  description = "データベース名"
  type        = string
}

variable "database_secret_arn" {
  description = "データベース認証情報が保存されているSecrets ManagerのARN"
  type        = string
}

variable "database_security_group_id" {
  description = "RDSデータベースのセキュリティグループID"
  type        = string
}

# ============================================
# ECS設定
# ============================================
variable "container_port" {
  description = "コンテナが待ち受けるポート番号"
  type        = number
  default     = 3000
}

variable "container_cpu" {
  description = "コンテナに割り当てるCPUユニット数（1024 = 1 vCPU）"
  type        = number
  default     = 256
}

variable "container_memory" {
  description = "コンテナに割り当てるメモリ（MiB）"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "ECSサービスで起動する desired タスク数"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "ヘルスチェックのパス"
  type        = string
  default     = "/"
}

