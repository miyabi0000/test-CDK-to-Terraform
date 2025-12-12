# ============================================
# Database Module - 変数定義
# ============================================

variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "environment" {
  description = "環境名"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "database_subnet_ids" {
  description = "データベースサブネットIDリスト"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDRブロック"
  type        = string
}

variable "app_security_group_id" {
  description = "アプリケーションセキュリティグループID"
  type        = string
  default     = ""
}

variable "database_name" {
  description = "データベース名"
  type        = string
}

variable "database_username" {
  description = "データベースユーザー名"
  type        = string
  default     = "dbadmin"
}

variable "database_instance_class" {
  description = "RDSインスタンスクラス"
  type        = string
}

variable "database_allocated_storage" {
  description = "ストレージサイズ（GB）"
  type        = number
  default     = 20
}

variable "database_engine_version" {
  description = "PostgreSQLバージョン"
  type        = string
}

variable "database_multi_az" {
  description = "マルチAZ有効化"
  type        = bool
}

variable "database_backup_retention_period" {
  description = "バックアップ保持期間（日数）"
  type        = number
  default     = 7
}

variable "enable_deletion_protection" {
  description = "削除保護有効化"
  type        = bool
}

