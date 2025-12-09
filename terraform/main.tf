# ============================================
# Terraformとプロバイダーの設定
# ============================================
# 
# このファイルの役割:
# - Terraformのバージョン指定
# - AWSプロバイダーの設定
# - デフォルトタグの設定（すべてのリソースに自動適用）

terraform {
  # Terraformのバージョン要件
  # ">= 1.0" = バージョン1.0以上を要求
  required_version = ">= 1.0"

  # 使用するプロバイダーの指定
  required_providers {
    # AWSプロバイダー
    aws = {
      source  = "hashicorp/aws"  # プロバイダーの取得元
      version = "~> 5.0"         # 5.x系を使用（5.0以上、6.0未満）
    }
    
    # Randomプロバイダー（パスワード生成等に使用）
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# AWSプロバイダーの設定
provider "aws" {
  # 使用するAWSリージョン（変数から取得）
  region = var.aws_region

  # デフォルトタグ: すべてのリソースに自動的に付与される
  # これにより、リソースの管理や課金分析が容易になる
  default_tags {
    tags = {
      Project     = "SAA-Learning"           # プロジェクト名
      ManagedBy   = "Terraform"              # Terraformで管理されていることを明示
      Environment = var.environment          # 環境名（dev/staging/production）
      CreatedBy   = "terraform-migration"    # 作成方法
    }
  }
}

# ============================================
# Networkingモジュールの呼び出し
# ============================================
# VPC、サブネット、ゲートウェイ、ルートテーブルを作成

module "networking" {
  source = "./modules/networking"
  
  # モジュールに渡す変数
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# このモジュール呼び出しにより、以下が作成されます:
# - VPC x1
# - インターネットゲートウェイ x1
# - サブネット x6（パブリック x2、プライベート x2、データベース x2）
# - NATゲートウェイ x1
# - ルートテーブル x3
# 合計: 約19個のリソース

