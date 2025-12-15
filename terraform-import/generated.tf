# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "saa-learning-app"
resource "aws_ecr_repository" "app" {
  force_delete         = null
  image_tag_mutability = "MUTABLE"
  name                 = "saa-learning-app"
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-app"
    Project     = "SAA-Learning"
  }
  tags_all = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-app"
    Project     = "SAA-Learning"
  }
  encryption_configuration {
    encryption_type = "AES256"
    kms_key         = null
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

# __generated__ by Terraform
resource "aws_db_instance" "main" {
  allocated_storage                     = 20
  allow_major_version_upgrade           = null
  apply_immediately                     = null
  auto_minor_version_upgrade            = true
  availability_zone                     = "ap-northeast-1c"
  backup_retention_period               = 7
  backup_target                         = "region"
  backup_window                         = "15:41-16:11"
  ca_cert_identifier                    = "rds-ca-rsa2048-g1"
  character_set_name                    = null
  copy_tags_to_snapshot                 = false
  custom_iam_instance_profile           = null
  customer_owned_ip_enabled             = false
  database_insights_mode                = "standard"
  db_name                               = "saalearningdb"
  db_subnet_group_name                  = "saa-learning-db-subnet-group"
  dedicated_log_volume                  = false
  delete_automated_backups              = true
  deletion_protection                   = false
  domain                                = null
  domain_auth_secret_arn                = null
  domain_dns_ips                        = []
  domain_fqdn                           = null
  domain_iam_role_name                  = null
  domain_ou                             = null
  enabled_cloudwatch_logs_exports       = []
  engine                                = "postgres"
  engine_lifecycle_support              = "open-source-rds-extended-support"
  engine_version                        = jsonencode(15.15)
  final_snapshot_identifier             = null
  iam_database_authentication_enabled   = false
  identifier                            = "saa-learning-db"
  identifier_prefix                     = null
  instance_class                        = "db.t3.micro"
  iops                                  = 0
  kms_key_id                            = "arn:aws:kms:ap-northeast-1:032710299553:key/1f848de8-0ba5-4ae4-bf68-dd6cb16f6969"
  license_model                         = "postgresql-license"
  maintenance_window                    = "mon:14:29-mon:14:59"
  manage_master_user_password           = null
  master_user_secret_kms_key_id         = null
  max_allocated_storage                 = 0
  monitoring_interval                   = 0
  monitoring_role_arn                   = null
  multi_az                              = false
  nchar_character_set_name              = null
  network_type                          = "IPV4"
  option_group_name                     = "default:postgres-15"
  parameter_group_name                  = "default.postgres15"
  password                              = null # sensitive
  password_wo                           = null # sensitive
  password_wo_version                   = null
  performance_insights_enabled          = false
  performance_insights_kms_key_id       = null
  performance_insights_retention_period = 0
  port                                  = 5432
  publicly_accessible                   = false
  replica_mode                          = null
  replicate_source_db                   = null
  skip_final_snapshot                   = true
  snapshot_identifier                   = null
  storage_encrypted                     = true
  storage_throughput                    = 0
  storage_type                          = "gp2"
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-db"
    Project     = "SAA-Learning"
  }
  tags_all = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-db"
    Project     = "SAA-Learning"
  }
  timezone               = null
  upgrade_storage_config = null
  username               = "dbadmin"
  vpc_security_group_ids = ["sg-0b9cc433e5b293f90"]
}

# __generated__ by Terraform
resource "aws_lb" "main" {
  client_keep_alive                                            = 3600
  customer_owned_ipv4_pool                                     = null
  desync_mitigation_mode                                       = "defensive"
  dns_record_client_routing_policy                             = null
  drop_invalid_header_fields                                   = false
  enable_cross_zone_load_balancing                             = true
  enable_deletion_protection                                   = false
  enable_http2                                                 = true
  enable_tls_version_and_cipher_suite_headers                  = false
  enable_waf_fail_open                                         = false
  enable_xff_client_port                                       = false
  enable_zonal_shift                                           = false
  enforce_security_group_inbound_rules_on_private_link_traffic = null
  idle_timeout                                                 = 60
  internal                                                     = false
  ip_address_type                                              = "ipv4"
  load_balancer_type                                           = "application"
  name                                                         = "saa-learning-alb"
  name_prefix                                                  = null
  preserve_host_header                                         = false
  security_groups                                              = ["sg-02e9e36fca7789793"]
  subnets                                                      = ["subnet-0c85b71ee0eccda1c", "subnet-0dcac01c0d730810c"]
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-alb"
    Project     = "SAA-Learning"
  }
  tags_all = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-alb"
    Project     = "SAA-Learning"
  }
  xff_header_processing_mode = "append"
  access_logs {
    bucket  = ""
    enabled = false
    prefix  = null
  }
  connection_logs {
    bucket  = ""
    enabled = false
    prefix  = null
  }
  subnet_mapping {
    allocation_id        = null
    ipv6_address         = null
    private_ipv4_address = null
    subnet_id            = "subnet-0c85b71ee0eccda1c"
  }
  subnet_mapping {
    allocation_id        = null
    ipv6_address         = null
    private_ipv4_address = null
    subnet_id            = "subnet-0dcac01c0d730810c"
  }
}

# __generated__ by Terraform
resource "aws_vpc" "main" {
  assign_generated_ipv6_cidr_block     = false
  cidr_block                           = "10.0.0.0/16"
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  enable_network_address_usage_metrics = false
  instance_tenancy                     = "default"
  ipv4_ipam_pool_id                    = null
  ipv4_netmask_length                  = null
  ipv6_cidr_block                      = null
  ipv6_cidr_block_network_border_group = null
  ipv6_ipam_pool_id                    = null
  ipv6_netmask_length                  = 0
  tags = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-vpc"
    Project     = "SAA-Learning"
  }
  tags_all = {
    CreatedBy   = "terraform-migration"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Name        = "saa-learning-vpc"
    Project     = "SAA-Learning"
  }
}
