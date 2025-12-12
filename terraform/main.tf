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

module "networking" {
  source = "./modules/networking"
  
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# ============================================
# Databaseモジュールの呼び出し
# ============================================

module "database" {
  source = "./modules/database"
  
  project_name                    = var.project_name
  environment                     = var.environment
  vpc_id                          = module.networking.vpc_id
  vpc_cidr_block                  = module.networking.vpc_cidr_block
  database_subnet_ids             = module.networking.database_subnet_ids
  database_name                   = var.database_name
  database_username               = var.database_username
  database_instance_class         = var.database_instance_class
  database_allocated_storage      = var.database_allocated_storage
  database_engine_version         = var.database_engine_version
  database_multi_az               = var.database_multi_az
  enable_deletion_protection      = var.enable_deletion_protection
}

# ============================================
# ECR Repository
# ============================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-app"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ============================================
# ECSモジュールの呼び出し
# ============================================

module "ecs" {
  source = "./modules/ecs"
  
  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  private_subnet_ids        = module.networking.private_subnet_ids
  ecr_repository_url        = aws_ecr_repository.app.repository_url
  database_endpoint         = module.database.db_address
  database_name             = var.database_name
  database_secret_arn       = module.database.secret_arn
  database_security_group_id = module.database.db_security_group_id
  container_port            = var.container_port
  container_cpu             = var.container_cpu
  container_memory          = var.container_memory
  desired_count             = var.desired_count
  health_check_path         = var.health_check_path
}

