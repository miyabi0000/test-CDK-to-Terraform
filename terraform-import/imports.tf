# ============================================
# Terraform 1.5+ Import Blocks
# ============================================
# 既存のAWSリソースをTerraform管理下に取り込む
# terraform plan -generate-config-out=generated.tf で自動コード生成

# VPC
import {
  to = aws_vpc.main
  id = "vpc-09dcb16efba7fab4a"
}

# ECR Repository
import {
  to = aws_ecr_repository.app
  id = "saa-learning-app"
}

# RDS Instance
import {
  to = aws_db_instance.main
  id = "saa-learning-db"
}

# ECS Cluster
import {
  to = aws_ecs_cluster.main
  id = "arn:aws:ecs:ap-northeast-1:032710299553:cluster/saa-learning-cluster"
}

# Application Load Balancer
import {
  to = aws_lb.main
  id = "arn:aws:elasticloadbalancing:ap-northeast-1:032710299553:loadbalancer/app/saa-learning-alb/164895653f44035d"
}

