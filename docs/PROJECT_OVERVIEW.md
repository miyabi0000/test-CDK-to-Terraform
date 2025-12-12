# CDK → Terraform 移行プロジェクト 完全ガイド

## 📋 目次
- [プロジェクト概要](#プロジェクト概要)
- [プロジェクト構造](#プロジェクト構造)
- [アーキテクチャ](#アーキテクチャ)
- [移行内容](#移行内容)
- [技術スタック](#技術スタック)
- [重要概念](#重要概念)

---

## 🎯 プロジェクト概要

### 目的
AWS CDK (TypeScript) で構築されたインフラを Terraform (HCL) に完全移行

### 成果
- **41個のAWSリソース**をTerraformで再構築
- **3層アーキテクチャ**（Network/Data/Application）
- **稼働中のWebアプリケーション**（Node.js + PostgreSQL）
- **モジュール化されたコード**（再利用可能）

### URL
```
http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com
```

---

## 📁 プロジェクト構造

```
cdk-docker-saa/
├── terraform/                    # Terraformコード（新規作成）
│   ├── main.tf                   # メイン設定（モジュール呼び出し）
│   ├── variables.tf              # 変数定義（パラメータ化）
│   ├── outputs.tf                # 出力値（URL等）
│   ├── .terraform.lock.hcl       # プロバイダーバージョン固定
│   └── modules/                  # モジュール（再利用可能な部品）
│       ├── networking/           # ネットワーク層
│       │   ├── main.tf          # VPC、Subnet、Gateway
│       │   ├── variables.tf     # 入力パラメータ
│       │   └── outputs.tf       # VPC ID等
│       ├── database/            # データ層
│       │   ├── main.tf          # RDS、Secrets Manager
│       │   ├── variables.tf     # DB設定
│       │   └── outputs.tf       # エンドポイント等
│       └── ecs/                 # アプリケーション層
│           ├── main.tf          # ECS、ALB、IAM
│           ├── variables.tf     # コンテナ設定
│           └── outputs.tf       # ALB URL等
│
├── docker-app/                   # アプリケーションコード
│   ├── Dockerfile               # コンテナイメージ定義
│   ├── server.js                # Node.js Express API
│   ├── package.json             # 依存関係
│   └── package-lock.json        # バージョン固定
│
├── docs/                         # ドキュメント
│   ├── PROJECT_OVERVIEW.md      # 本ドキュメント
│   ├── MIGRATION_PLAN.md        # 移行計画
│   ├── PHASE1_SETUP_GUIDE.md    # セットアップ手順
│   ├── PHASE4_APPLICATION_GUIDE.md # アプリ層詳細
│   └── MIGRATION_COMPLETED.md   # 完了レポート
│
├── lib/                         # 元のCDKコード（参考用）
└── .gitignore                   # Git除外設定（Terraform対応）
```

---

## 🏗️ アーキテクチャ

### 全体構成図

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP (80)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                  Application Load Balancer                  │
│                    (Public Subnets)                         │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP (3000)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              ECS Fargate (Private Subnets)                  │
│  ┌──────────────────────────────────────────────────┐       │
│  │  Node.js Container (Express)                     │       │
│  │  - Port: 3000                                    │       │
│  │  - Env: DATABASE_HOST, DATABASE_NAME, PORT       │       │
│  │  - Secrets: USERNAME, PASSWORD                   │       │
│  └──────────────────────────────────────────────────┘       │
└────────────────────────┬────────────────────────────────────┘
                         │ PostgreSQL (5432)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│            RDS PostgreSQL (Database Subnets)                │
│                 - Version: 15.15                            │
│                 - Instance: db.t3.micro                     │
│                 - Storage: 20GB (encrypted)                 │
└─────────────────────────────────────────────────────────────┘
```

### ネットワーク構成（VPC）

```
VPC (10.0.0.0/16)
├── Public Subnets (Internet Gateway経由)
│   ├── 10.0.0.0/24 (ap-northeast-1a) ← ALB配置
│   └── 10.0.1.0/24 (ap-northeast-1c) ← ALB配置
│
├── Private Subnets (NAT Gateway経由)
│   ├── 10.0.128.0/24 (ap-northeast-1a) ← ECS配置
│   └── 10.0.129.0/24 (ap-northeast-1c) ← ECS配置
│
└── Database Subnets (隔離)
    ├── 10.0.20.0/24 (ap-northeast-1a) ← RDS配置
    └── 10.0.21.0/24 (ap-northeast-1c) ← RDS配置
```

### セキュリティグループ

```
Internet → ALB SG (Port 80) → ECS SG (Port 3000) → DB SG (Port 5432)
           ↓ Ingress          ↓ Ingress           ↓ Ingress
           0.0.0.0/0          ALB SG only         VPC CIDR only
```

---

## 🔄 移行内容

### Phase 1: Terraform環境セットアップ

**目的**: Terraformの実行環境を準備

| 作業 | 内容 | 成果物 |
|-----|------|--------|
| インストール確認 | `terraform --version` | Terraform v1.x |
| 構造作成 | ディレクトリ・モジュール設計 | `terraform/modules/` |
| プロバイダー設定 | AWS Provider 5.x | `main.tf`, `variables.tf` |
| 初期化 | `terraform init` | `.terraform/`, `.terraform.lock.hcl` |

**キーポイント**:
- モジュール化による再利用性
- 変数によるパラメータ化
- バージョン固定による再現性

---

### Phase 2: ネットワーク層（11リソース）

**目的**: VPCとサブネット、ルーティングを構築

#### 作成したリソース

| カテゴリ | リソース | 役割 | 数量 |
|---------|---------|------|------|
| **VPC** | VPC | ネットワーク全体の基盤 | 1 |
| **Subnet** | Public Subnet | ALB配置、IGW接続 | 2 (Multi-AZ) |
| **Subnet** | Private Subnet | ECS配置、NAT GW接続 | 2 (Multi-AZ) |
| **Subnet** | Database Subnet | RDS配置、隔離 | 2 (Multi-AZ) |
| **Gateway** | Internet Gateway | Public→Internet | 1 |
| **Gateway** | NAT Gateway | Private→Internet | 1 |
| **IP** | Elastic IP | NAT Gateway用固定IP | 1 |
| **Route** | Route Table | トラフィック制御 | 3 |

#### ネットワークフロー

```
Public Subnet:
└─ 0.0.0.0/0 → Internet Gateway → Internet

Private Subnet:
└─ 0.0.0.0/0 → NAT Gateway → Internet Gateway → Internet

Database Subnet:
└─ (外部通信なし、VPC内のみ)
```

#### なぜ3種類のサブネット？

| Subnet種別 | 用途 | 外部通信 | 理由 |
|-----------|------|---------|------|
| **Public** | ALB | 可能 | インターネットから直接アクセス必要 |
| **Private** | ECS | NAT経由 | セキュリティ（直接公開しない） |
| **Database** | RDS | 不可 | 最高のセキュリティ（完全隔離） |

---

### Phase 3: データ層（6リソース）

**目的**: データベースとコンテナレジストリを構築

#### 作成したリソース

| カテゴリ | リソース | 役割 | 設定 |
|---------|---------|------|------|
| **ECR** | Repository | Dockerイメージ保管 | `saa-learning-app` |
| **ECR** | Lifecycle Policy | 古いイメージ削除 | 最新10個保持 |
| **RDS** | PostgreSQL | データベース | 15.15, db.t3.micro |
| **RDS** | DB Subnet Group | RDS配置先 | 2サブネット |
| **RDS** | Security Group | アクセス制御 | VPCからのみ許可 |
| **Secrets** | Secrets Manager | DB認証情報 | User/Pass暗号化保存 |

#### RDS設定詳細

```
Engine: PostgreSQL 15.15
Instance: db.t3.micro (2vCPU, 1GB RAM)
Storage: 20GB (gp2, encrypted)
Backup: 7日保持
Multi-AZ: 無効（コスト削減、学習用）
Public: 無効（セキュリティ）
```

#### Secrets Manager構造

```json
{
  "username": "dbadmin",
  "password": "<auto-generated-16-chars>",
  "engine": "postgres",
  "host": "saa-learning-db.xxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "saalearningdb"
}
```

---

### Phase 4: アプリケーション層（14リソース）

**目的**: コンテナアプリケーションを実行・公開

#### 作成したリソース

| カテゴリ | リソース | 役割 |
|---------|---------|------|
| **Logs** | CloudWatch Logs | ECSログ保存（7日） |
| **IAM** | Task Execution Role | ECRプル、ログ送信、Secrets取得 |
| **IAM** | Task Role | アプリからAWSアクセス（現在空） |
| **IAM** | Secrets Policy | Secrets Manager読み取り権限 |
| **SG** | ALB Security Group | HTTP 80 from Internet |
| **SG** | ECS Security Group | Port 3000 from ALB only |
| **SG** | DB Ingress Rule | Port 5432 from ECS only |
| **ALB** | Load Balancer | トラフィック分散 |
| **ALB** | Target Group | ECSタスク登録先 |
| **ALB** | Listener | Port 80 → Target Group |
| **ECS** | Cluster | コンテナ管理 |
| **ECS** | Task Definition | コンテナ実行設定 |
| **ECS** | Service | タスク継続実行 |

#### ECS Task Definition構造

```yaml
Family: saa-learning-task
CPU: 256 (0.25 vCPU)
Memory: 512 MiB
Network Mode: awsvpc (Fargate必須)

Container:
  Name: saa-learning-container
  Image: <ECR-URL>:latest
  Port: 3000
  
  Environment Variables:
    - DATABASE_HOST: <RDS-Endpoint>
    - DATABASE_NAME: saalearningdb
    - PORT: 3000
  
  Secrets (from Secrets Manager):
    - DATABASE_USERNAME
    - DATABASE_PASSWORD
  
  Logging:
    Driver: awslogs
    Group: /ecs/saa-learning
    Region: ap-northeast-1
```

#### IAM Role分離

| Role | 使用者 | 用途 | 権限例 |
|------|-------|------|--------|
| **Execution Role** | ECS自身 | インフラ操作 | ECR Pull, CloudWatch Logs, Secrets Manager |
| **Task Role** | アプリコード | AWSサービス利用 | S3, DynamoDB, SQS（必要に応じて追加） |

#### ALBフロー

```
Internet (HTTP:80)
  ↓
ALB Listener
  ↓
Target Group (Health Check: GET /)
  ↓
ECS Task (10.0.128.98:3000)
  ↓
Container Response
```

---

## 📦 技術スタック

### Infrastructure as Code

| 項目 | 移行前 (CDK) | 移行後 (Terraform) |
|------|-------------|-------------------|
| **言語** | TypeScript | HCL |
| **抽象度** | 高（L2 Construct） | 低（直接リソース定義） |
| **状態管理** | CloudFormation | Terraform State |
| **実行** | `cdk deploy` | `terraform apply` |
| **プレビュー** | `cdk diff` | `terraform plan` |

### アプリケーション

| レイヤー | 技術 | バージョン |
|---------|------|-----------|
| **Runtime** | Node.js | 18-alpine |
| **Framework** | Express | ^4.18.2 |
| **Database Client** | pg | ^8.11.3 |
| **Container** | Docker | - |
| **Orchestration** | ECS Fargate | - |

### AWS Services

| カテゴリ | サービス | 用途 |
|---------|---------|------|
| **Network** | VPC, Subnets, IGW, NAT GW | ネットワーク基盤 |
| **Compute** | ECS Fargate | コンテナ実行 |
| **Load Balancer** | ALB | トラフィック分散 |
| **Database** | RDS PostgreSQL | データ永続化 |
| **Storage** | ECR | イメージ保管 |
| **Security** | IAM, Security Groups, Secrets Manager | アクセス制御・認証 |
| **Monitoring** | CloudWatch Logs | ログ管理 |

---

## 💡 重要概念

### 1. モジュール化

**目的**: コードの再利用性と保守性向上

```hcl
# メインファイルからモジュールを呼び出す
module "networking" {
  source = "./modules/networking"
  
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  # ...
}

# モジュールの出力を他のモジュールで使用
module "database" {
  source = "./modules/database"
  
  vpc_id     = module.networking.vpc_id  # ← networking出力を使用
  subnet_ids = module.networking.database_subnet_ids
  # ...
}
```

**メリット**:
- 変更箇所が明確
- テスト容易
- 環境（dev/prod）で再利用可能

---

### 2. Multi-AZ構成

**目的**: 高可用性

```
AZ-a (ap-northeast-1a)        AZ-c (ap-northeast-1c)
├── Public Subnet            ├── Public Subnet
├── Private Subnet           ├── Private Subnet
└── Database Subnet          └── Database Subnet
```

**メリット**:
- 1つのAZが障害でもサービス継続
- ALBが自動的にトラフィック振り分け
- RDSでMulti-AZ有効化すると自動フェイルオーバー

---

### 3. セキュリティレイヤー

**3層防御**:

```
Layer 1: Network (Subnet)
└─ Public: 公開
└─ Private: NAT経由のみ
└─ Database: 完全隔離

Layer 2: Security Group (Firewall)
└─ ALB SG: Port 80 from Internet
└─ ECS SG: Port 3000 from ALB only
└─ DB SG: Port 5432 from ECS only

Layer 3: IAM (Authentication)
└─ Execution Role: インフラ操作権限
└─ Task Role: アプリ実行権限
└─ Secrets Manager: 認証情報暗号化
```

---

### 4. 環境変数 vs Secrets

**使い分け**:

| 種類 | 用途 | 例 | 保存方法 |
|------|------|----|---------| 
| **環境変数** | 非機密情報 | DATABASE_HOST, PORT | Task Definition（平文） |
| **Secrets** | 機密情報 | USERNAME, PASSWORD | Secrets Manager（暗号化） |

**Secrets取得フロー**:
```
1. Task Definition に Secrets Manager ARN を記載
2. ECS が起動時に自動取得（Execution Role権限必要）
3. 環境変数としてコンテナに注入
4. アプリは通常の環境変数として読み取り
```

---

### 5. Terraform State

**目的**: 現在のインフラ状態を記録

```
terraform apply
  ↓
実際のAWSリソース作成
  ↓
terraform.tfstate に記録
  ↓
次回の terraform plan で差分検出
```

**重要**:
- `.tfstate` ファイルは機密情報含む → `.gitignore`
- 本番環境では S3 + DynamoDB で管理推奨
- チーム開発ではロック機構必要

---

### 6. Terraformコマンドフロー

```bash
# 1. 初期化（プロバイダーダウンロード）
terraform init

# 2. 検証（構文チェック）
terraform validate

# 3. プレビュー（変更内容確認）
terraform plan

# 4. 実行（リソース作成・更新）
terraform apply

# 5. 確認（出力値表示）
terraform output

# 6. 削除（全リソース削除）
terraform destroy
```

---

## 📊 リソース一覧

### 全41リソース

| Phase | カテゴリ | リソース数 | 主要リソース |
|-------|---------|-----------|------------|
| **Phase 2** | Network | 11 | VPC, Subnets, IGW, NAT GW |
| **Phase 3** | Data | 6 | RDS, ECR, Secrets Manager |
| **Phase 4** | Application | 14 | ALB, ECS, IAM Roles |
| **合計** | - | **41** | - |

### コスト概算（月額）

| リソース | 概算コスト | 備考 |
|---------|-----------|------|
| NAT Gateway | ~$32 | 最大コスト要因 |
| ALB | ~$20 | 基本料金+トラフィック |
| RDS (db.t3.micro) | ~$15 | Single-AZ |
| ECS Fargate | ~$10 | 0.25vCPU, 512MB |
| その他 | ~$2 | ECR, Logs, Secrets |
| **合計** | **~$79/月** | 学習環境 |

**コスト削減Tips**:
- 使わない時は `terraform destroy`
- NAT Gateway削除（Privateサブネット不使用）
- RDSをt4g.microに変更
- Multi-AZ無効化

---

## 🔧 運用コマンド

### デプロイ

```bash
# 変更確認
cd terraform
terraform plan

# デプロイ
terraform apply

# 出力確認
terraform output
```

### アプリケーション更新

```bash
# イメージビルド
cd docker-app
docker buildx build --platform linux/amd64 -t saa-learning-app:latest .

# ECRログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com

# プッシュ
docker tag saa-learning-app:latest \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest
docker push \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest

# ECS再起動
aws ecs update-service --cluster saa-learning-cluster \
  --service saa-learning-service --force-new-deployment
```

### ログ確認

```bash
# リアルタイム
aws logs tail /ecs/saa-learning --follow

# 最新5分
aws logs tail /ecs/saa-learning --since 5m
```

### ヘルスチェック

```bash
# ECSタスク
aws ecs describe-services --cluster saa-learning-cluster \
  --services saa-learning-service

# ALBターゲット
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# アプリケーション
curl http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com/health
```

---

## 🎓 学習ポイント

### CDK vs Terraform

| 観点 | CDK | Terraform |
|------|-----|-----------|
| **学習曲線** | TypeScript知識必要 | HCL構文のみ |
| **抽象度** | 高（数行でVPC作成） | 低（全設定明示） |
| **柔軟性** | プログラムロジック可 | 宣言的のみ |
| **可視性** | CloudFormation経由 | 直接的 |
| **マルチクラウド** | AWS専用 | 対応 |
| **エコシステム** | AWS公式 | コミュニティ主導 |

### アーキテクチャパターン

1. **3-Tier Architecture**: Presentation / Application / Data
2. **Multi-AZ**: 高可用性
3. **Private Subnet**: セキュリティ
4. **Least Privilege**: 最小権限の原則
5. **Infrastructure as Code**: コード化による管理

### AWSベストプラクティス

- ✅ VPC内でリソース隔離
- ✅ Security Groupで最小権限
- ✅ IAM Roleで認証情報管理
- ✅ Secrets Managerで機密情報暗号化
- ✅ CloudWatch Logsでログ集約
- ✅ Multi-AZで冗長化
- ✅ タグ付けでリソース管理

---

## 📚 参考ドキュメント

### 本プロジェクト

- [MIGRATION_PLAN.md](./MIGRATION_PLAN.md) - 移行計画詳細
- [PHASE1_SETUP_GUIDE.md](./PHASE1_SETUP_GUIDE.md) - 環境構築手順
- [PHASE4_APPLICATION_GUIDE.md](./PHASE4_APPLICATION_GUIDE.md) - アプリ層詳細
- [MIGRATION_COMPLETED.md](./MIGRATION_COMPLETED.md) - 完了レポート

### 公式ドキュメント

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS VPC Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)

---

## 🎉 まとめ

### 達成したこと

- ✅ **41個のAWSリソース**をTerraformで構築
- ✅ **モジュール化されたコード**（再利用可能）
- ✅ **稼働中のアプリケーション**（Node.js + PostgreSQL）
- ✅ **セキュアなアーキテクチャ**（3層防御）
- ✅ **完全なドキュメント**（初学者対応）

### 習得したスキル

- Terraform基礎（HCL、モジュール、State）
- AWSネットワーキング（VPC、Subnet、Gateway）
- コンテナ技術（Docker、ECS Fargate）
- セキュリティ（IAM、SG、Secrets Manager）
- Infrastructure as Code のベストプラクティス

### 次のステップ

1. **環境分離**: dev/staging/prod
2. **CI/CD**: GitHub Actions
3. **Monitoring**: CloudWatch Alarms + SNS
4. **Auto Scaling**: CPU/メモリベース
5. **HTTPS**: ACM証明書 + ALB HTTPS Listener

---

**完成したアプリケーション**: http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com

**プロジェクト完了！** 🚀

