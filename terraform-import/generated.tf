# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "saa-learning-app"
resource "aws_ecr_repository" "app" {
  image_tag_mutability = "MUTABLE"
  name                 = "saa-learning-app"
  
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-app"
    Project     = "SAA-Learning"
  }
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# __generated__ by Terraform
resource "aws_db_instance" "main" {
  # 基本設定
  identifier          = "saa-learning-db"
  engine              = "postgres"
  engine_version      = jsonencode(15.15)
  instance_class      = "db.t3.micro"
  
  # ストレージ設定
  allocated_storage   = 20
  storage_type        = "gp2"
  storage_encrypted   = true
  kms_key_id          = "arn:aws:kms:ap-northeast-1:032710299553:key/1f848de8-0ba5-4ae4-bf68-dd6cb16f6969"
  
  # データベース設定
  db_name             = "saalearningdb"
  username            = "dbadmin"
  # password は Secrets Manager経由で設定
  
  # ネットワーク設定
  db_subnet_group_name   = "saa-learning-db-subnet-group"
  vpc_security_group_ids = ["sg-0b9cc433e5b293f90"]
  publicly_accessible    = false
  availability_zone      = "ap-northeast-1c"
  multi_az               = false
  
  # バックアップ設定
  backup_retention_period = 7
  backup_window           = "15:41-16:11"
  skip_final_snapshot     = true
  delete_automated_backups = true
  
  # メンテナンス設定
  maintenance_window         = "mon:14:29-mon:14:59"
  auto_minor_version_upgrade = true
  
  # セキュリティ設定
  deletion_protection = false
  
  # その他の設定
  copy_tags_to_snapshot       = false
  iam_database_authentication_enabled = false
  performance_insights_enabled        = false
  
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-db"
    Project     = "SAA-Learning"
  }
}

# __generated__ by Terraform
resource "aws_lb" "main" {
  name               = "saa-learning-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-02e9e36fca7789793"]
  subnets            = ["subnet-0c85b71ee0eccda1c", "subnet-0dcac01c0d730810c"]
  
  # セキュリティ設定
  enable_deletion_protection = false
  drop_invalid_header_fields = false
  desync_mitigation_mode     = "defensive"
  
  # 機能設定
  enable_cross_zone_load_balancing = true
  enable_http2                     = true
  idle_timeout                     = 60
  
  # ログ設定（無効化）
  access_logs {
    bucket  = ""
    enabled = false
  }
  
  connection_logs {
    bucket  = ""
    enabled = false
  }
  
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-alb"
    Project     = "SAA-Learning"
  }
}

# __generated__ by Terraform
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-vpc"
    Project     = "SAA-Learning"
  }
}
