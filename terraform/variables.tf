# ============================================
# 変数定義ファイル
# ============================================
#
# このファイルの役割:
# - プロジェクト全体で使用する変数を定義
# - デフォルト値の設定
# - 変数の型と説明を明記
#
# 変数の使い方:
# - コード内で var.変数名 として参照
# - terraform.tfvars で値を上書き可能
# - コマンドラインで -var="変数名=値" として指定可能

# ============================================
# 基本設定
# ============================================

variable "aws_region" {
  description = "AWSリージョン（デプロイ先の地理的な場所）"
  type        = string
  default     = "ap-northeast-1"  # 東京リージョン
  
  # 他のリージョン例:
  # - us-east-1: 米国バージニア北部
  # - eu-west-1: アイルランド
  # - ap-southeast-1: シンガポール
}

variable "environment" {
  description = "環境名（開発/ステージング/本番を区別）"
  type        = string
  default     = "dev"
  
  # 想定される値:
  # - dev: 開発環境
  # - staging: ステージング環境（本番前のテスト）
  # - production: 本番環境
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "環境名は dev, staging, production のいずれかである必要があります。"
  }
}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスに使用）"
  type        = string
  default     = "saa-learning"
  
  # リソース名の例:
  # - VPC: saa-learning-vpc
  # - RDS: saa-learning-db
  # - ECS Cluster: saa-learning-cluster
}

# ============================================
# ネットワーク設定
# ============================================

variable "vpc_cidr" {
  description = "VPCのCIDRブロック（IPアドレスの範囲）"
  type        = string
  default     = "10.0.0.0/16"
  
  # CIDR解説:
  # - 10.0.0.0/16 = 10.0.0.0 〜 10.0.255.255 まで（65,536個のIPアドレス）
  # - /16 = サブネットマスク 255.255.0.0
  # - VPC内で使えるIPアドレスの範囲を定義
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン（データセンターの場所）"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
  
  # アベイラビリティゾーン（AZ）とは:
  # - 物理的に分離されたデータセンター
  # - 複数AZを使うことで高可用性を実現
  # - 1つのAZが障害でも、もう1つのAZでサービス継続
}

# ============================================
# データベース設定
# ============================================

variable "database_name" {
  description = "RDSデータベース名"
  type        = string
  default     = "saalearningdb"
  
  # データベース名の制約:
  # - 英数字とアンダースコアのみ
  # - 先頭は英字
}

variable "database_username" {
  description = "RDSデータベースのマスターユーザー名"
  type        = string
  default     = "dbadmin"
  
  # セキュリティ注意:
  # - 本番環境では terraform.tfvars に記載し、.gitignore に追加
  # - または環境変数から取得
}

variable "database_instance_class" {
  description = "RDSインスタンスクラス（サーバーのスペック）"
  type        = string
  default     = "db.t3.micro"
  
  # インスタンスクラス解説:
  # - db.t3.micro: 2vCPU, 1GB RAM（学習・開発用）
  # - db.t3.small: 2vCPU, 2GB RAM
  # - db.t3.medium: 2vCPU, 4GB RAM（小規模本番環境）
  # - db.m5.large: 2vCPU, 8GB RAM（中規模本番環境）
}

variable "database_allocated_storage" {
  description = "RDSストレージサイズ（GB）"
  type        = number
  default     = 20
  
  # ストレージタイプ:
  # - gp2: 汎用SSD（コスパ良い）
  # - gp3: 新世代汎用SSD（gp2より高性能）
  # - io1: プロビジョンドIOPS SSD（高性能、高コスト）
}

variable "database_engine_version" {
  description = "PostgreSQLのバージョン"
  type        = string
  default     = "15.15"
  
  # 利用可能なバージョン:
  # - 15.x: 最新系（新機能が使える）
  # - 14.x: 安定版
  # - 13.x: 長期サポート
}

variable "database_multi_az" {
  description = "マルチAZ配置を有効化するか（高可用性）"
  type        = bool
  default     = false  # 学習用のためコスト削減
  
  # マルチAZ配置の効果:
  # - true: 別のAZに自動的にスタンバイDBを作成
  # - 障害時に自動フェイルオーバー（30秒〜2分）
  # - コストは約2倍になる
  # - 本番環境では true を推奨
}

# ============================================
# ECS/コンテナ設定
# ============================================

variable "container_cpu" {
  description = "コンテナに割り当てるCPUユニット数（1024 = 1 vCPU）"
  type        = number
  default     = 256
  
  # CPU値の意味:
  # - 256 = 0.25 vCPU
  # - 512 = 0.5 vCPU
  # - 1024 = 1 vCPU
  # - 2048 = 2 vCPU
}

variable "container_memory" {
  description = "コンテナに割り当てるメモリ（MiB）"
  type        = number
  default     = 512
  
  # メモリ値の意味:
  # - 512 = 512MB = 0.5GB
  # - 1024 = 1GB
  # - 2048 = 2GB
  # 
  # CPU 256 の場合のメモリ選択肢:
  # - 512, 1024, 2048
}

variable "desired_count" {
  description = "ECSサービスで起動する desired タスク数"
  type        = number
  default     = 1
  
  # タスク数の考え方:
  # - 1: 単一タスク（学習用、コスト最小）
  # - 2: 冗長構成（1つが落ちても大丈夫）
  # - 3以上: 高負荷対応
}

variable "container_port" {
  description = "コンテナが待ち受けるポート番号"
  type        = number
  default     = 3000
  
  # ポート番号解説:
  # - 3000: Node.jsアプリケーションのデフォルト
  # - ALBは80番で受けて、コンテナの3000に転送
}

variable "health_check_path" {
  description = "ヘルスチェックのパス"
  type        = string
  default     = "/"
  
  # ヘルスチェック解説:
  # - ALBがコンテナの健全性を確認するためのエンドポイント
  # - 200 OKを返すパスを指定
}

# ============================================
# その他の設定
# ============================================

variable "enable_deletion_protection" {
  description = "リソースの削除保護を有効化（本番環境推奨）"
  type        = bool
  default     = false
  
  # 削除保護の効果:
  # - true: terraform destroy で削除できない
  # - 誤って本番環境を削除するのを防ぐ
  # - 学習用では false でOK
}

variable "log_retention_days" {
  description = "CloudWatch Logsの保持期間（日数）"
  type        = number
  default     = 7
  
  # 保持期間の選択肢:
  # - 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
  # - 長期保存はコストが増える
  # - コンプライアンス要件に応じて設定
}

