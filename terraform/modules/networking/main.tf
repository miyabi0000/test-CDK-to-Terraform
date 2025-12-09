# ============================================
# Networking Module - VPCとサブネット構成
# ============================================
#
# このモジュールの役割:
# - VPCの作成（仮想プライベートクラウド）
# - マルチAZ構成のサブネット作成
# - インターネットゲートウェイとNATゲートウェイの設定
# - ルートテーブルの設定と関連付け
#
# アーキテクチャ:
# VPC (10.0.0.0/16)
# ├── AZ1 (ap-northeast-1a)
# │   ├── Public Subnet (10.0.0.0/24)
# │   ├── Private Subnet (10.0.128.0/24)
# │   └── Database Subnet (10.0.256.0/24)
# └── AZ2 (ap-northeast-1c)
#     ├── Public Subnet (10.0.1.0/24)
#     ├── Private Subnet (10.0.129.0/24)
#     └── Database Subnet (10.0.257.0/24)

# ============================================
# VPCの作成
# ============================================
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr  # 10.0.0.0/16（65,536個のIPアドレス）

  # DNS機能を有効化（重要）
  enable_dns_hostnames = true  # EC2インスタンスにDNS名を付与
  enable_dns_support   = true  # VPC内でDNS解決を有効化

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ============================================
# インターネットゲートウェイ
# ============================================
# 役割: VPCとインターネット間の通信を可能にする
# 用途: パブリックサブネットのリソースがインターネットにアクセスするため

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ============================================
# パブリックサブネット
# ============================================
# 役割: インターネットから直接アクセス可能なサブネット
# 用途: Application Load Balancer (ALB) を配置

resource "aws_subnet" "public" {
  count = length(var.availability_zones)  # AZの数だけサブネットを作成

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  # cidrsubnet解説:
  # - cidrsubnet("10.0.0.0/16", 8, 0) → "10.0.0.0/24"
  # - cidrsubnet("10.0.0.0/16", 8, 1) → "10.0.1.0/24"
  # - 8bit拡張 → /16 から /24 へ
  
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true  # このサブネットで起動したEC2は自動的にパブリックIPを取得

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Type = "Public"
  }
}

# ============================================
# プライベートサブネット
# ============================================
# 役割: インターネットから直接アクセスできないが、外部への通信は可能
# 用途: ECSタスク（アプリケーションコンテナ）を配置

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 128)
  # +128の理由:
  # - count.index + 128 → 0+128=128, 1+128=129
  # - cidrsubnet("10.0.0.0/16", 8, 128) → "10.0.128.0/24"
  # - cidrsubnet("10.0.0.0/16", 8, 129) → "10.0.129.0/24"
  # - パブリックサブネットと重複しないようにオフセット
  
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Type = "Private"
  }
}

# ============================================
# データベースサブネット
# ============================================
# 役割: 完全に隔離されたサブネット（インターネットへの出口もなし）
# 用途: RDS データベースを配置（セキュリティのため）

resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  # +20の理由:
  # - count.index + 20 → 0+20=20, 1+20=21
  # - cidrsubnet("10.0.0.0/16", 8, 20) → "10.0.20.0/24"
  # - cidrsubnet("10.0.0.0/16", 8, 21) → "10.0.21.0/24"
  # - パブリック（0-1）、プライベート（128-129）と重複しない範囲
  
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-database-${count.index + 1}"
    Type = "Database"
  }
}

# ============================================
# Elastic IP for NAT Gateway
# ============================================
# 役割: NATゲートウェイに固定のパブリックIPアドレスを割り当てる
# なぜ必要: プライベートサブネットからのアウトバウンド通信に使用

resource "aws_eip" "nat" {
  domain = "vpc"  # VPC用のElastic IP

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  # depends_on: リソースの作成順序を明示的に指定
  # IGWが先に作成されないと、EIPの割り当てが失敗する可能性がある
  depends_on = [aws_internet_gateway.main]
}

# ============================================
# NAT Gateway
# ============================================
# 役割: プライベートサブネットのリソースがインターネットにアクセスできるようにする
# 仕組み: プライベートIPをパブリックIPに変換（NAT: Network Address Translation）

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id         # 上で作成したElastic IPを使用
  subnet_id     = aws_subnet.public[0].id  # パブリックサブネットに配置

  tags = {
    Name = "${var.project_name}-nat"
  }

  # NATゲートウェイはインターネットゲートウェイに依存
  depends_on = [aws_internet_gateway.main]
}

# コスト削減ポイント:
# - NATゲートウェイは1つのみ（本番環境では各AZに1つ推奨）
# - 料金: 約$0.045/時間 + データ転送料
# - 高可用性が必要な場合は、各AZにNATゲートウェイを配置

# ============================================
# ルートテーブル: パブリックサブネット用
# ============================================
# 役割: パブリックサブネットの通信経路を定義

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # デフォルトルート: 0.0.0.0/0（すべての宛先）
  route {
    cidr_block = "0.0.0.0/0"               # すべてのIPアドレス宛て
    gateway_id = aws_internet_gateway.main.id  # インターネットゲートウェイ経由
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 意味: パブリックサブネットからは、すべての外部通信がIGW経由でインターネットへ

# ============================================
# ルートテーブル: プライベートサブネット用
# ============================================
# 役割: プライベートサブネットの通信経路を定義

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"             # すべてのIPアドレス宛て
    nat_gateway_id = aws_nat_gateway.main.id  # NATゲートウェイ経由
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# 意味: プライベートサブネットからは、外部通信がNATゲートウェイ経由でインターネットへ
# インバウンド（外→内）は不可、アウトバウンド（内→外）のみ可能

# ============================================
# ルートテーブル: データベースサブネット用
# ============================================
# 役割: データベースサブネットの通信経路を定義

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  # ルートなし = インターネットへの接続なし
  # データベースは完全に隔離される

  tags = {
    Name = "${var.project_name}-database-rt"
  }
}

# セキュリティポイント:
# - ルートが定義されていない = インターネットへの出口なし
# - VPC内の通信のみ可能（ECSタスク → RDS）
# - 外部からの侵入リスクを最小化

# ============================================
# ルートテーブルの関連付け: パブリックサブネット
# ============================================
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================
# ルートテーブルの関連付け: プライベートサブネット
# ============================================
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================
# ルートテーブルの関連付け: データベースサブネット
# ============================================
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# ============================================
# まとめ
# ============================================
# このモジュールで作成されるリソース:
# - VPC x1
# - インターネットゲートウェイ x1
# - パブリックサブネット x2
# - プライベートサブネット x2
# - データベースサブネット x2
# - Elastic IP x1
# - NATゲートウェイ x1
# - ルートテーブル x3
# - ルートテーブル関連付け x6
#
# 合計: 19個のリソース
#
# CDKとの比較:
# - CDK: new ec2.Vpc() 1行
# - Terraform: 約200行
#
# Terraformの利点:
# - すべてのリソースが明示的
# - 細かいカスタマイズが可能
# - トラブルシューティングが容易

