# ============================================
# Networking Module - 変数定義
# ============================================
#
# このファイルの役割:
# - Networkingモジュールで使用する変数を定義
# - 呼び出し元（rootモジュール）から値を受け取る

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックスとして使用）"
  type        = string
  
  # 例: "saa-learning" → リソース名は "saa-learning-vpc", "saa-learning-igw" など
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  
  # 例: "10.0.0.0/16"
  # これにより、10.0.0.0 〜 10.0.255.255 の範囲のIPアドレスが使用可能
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーンのリスト"
  type        = list(string)
  
  # 例: ["ap-northeast-1a", "ap-northeast-1c"]
  # この数だけサブネットが作成される（パブリック、プライベート、データベースそれぞれ）
}

