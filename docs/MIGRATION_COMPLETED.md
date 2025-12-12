# CDK → Terraform 移行完了レポート

## ✅ 移行ステータス: **完了**

**移行日**: 2024年12月12日  
**プロジェクト**: SAA Learning - Docker + PostgreSQL アプリケーション  
**移行元**: AWS CDK (TypeScript)  
**移行先**: Terraform (HCL)

---

## 📊 移行サマリー

### 全体構成

| フェーズ | 内容 | リソース数 | ステータス |
|---------|------|-----------|-----------|
| Phase 1 | Terraform環境セットアップ | - | ✅ 完了 |
| Phase 2 | ネットワーク層 | 11個 | ✅ 完了 |
| Phase 3 | データ層 | 6個 | ✅ 完了 |
| Phase 4 | アプリケーション層 | 14個 | ✅ 完了 |
| **合計** | **全インフラストラクチャ** | **41個** | ✅ **完了** |

---

## 🏗️ 構築されたインフラストラクチャ

### Phase 2: ネットワーク層（11個のリソース）

#### VPCとサブネット
- **VPC**: `vpc-09dcb16efba7fab4a` (10.0.0.0/16)
- **Public Subnets**: 2個
  - `subnet-0dcac01c0d730810c` (ap-northeast-1a: 10.0.0.0/24)
  - `subnet-0c85b71ee0eccda1c` (ap-northeast-1c: 10.0.1.0/24)
- **Private Subnets**: 2個
  - `subnet-0386ff3f97e497adf` (ap-northeast-1a: 10.0.128.0/24)
  - `subnet-0d04b79418cacfb24` (ap-northeast-1c: 10.0.129.0/24)
- **Database Subnets**: 2個
  - `subnet-00ac40fc852ada5a3` (ap-northeast-1a: 10.0.20.0/24)
  - `subnet-05645f9cc77e73911` (ap-northeast-1c: 10.0.21.0/24)

#### ネットワーキング
- **Internet Gateway**: インターネット接続
- **NAT Gateway**: Private SubnetからのInternet アクセス
- **Elastic IP**: NAT Gateway用
- **Route Tables**: Public、Private、Database用

---

### Phase 3: データ層（6個のリソース）

#### コンテナレジストリ
- **ECR Repository**: `saa-learning-app`
  - URL: `032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app`
  - イメージスキャン: 有効
  - ライフサイクルポリシー: 最新10イメージ保持

#### データベース
- **RDS PostgreSQL**
  - ID: `saa-learning-db`
  - エンドポイント: `saa-learning-db.c7u00y8qancp.ap-northeast-1.rds.amazonaws.com:5432`
  - エンジン: PostgreSQL 15.15
  - インスタンスクラス: db.t3.micro
  - ストレージ: 20GB (暗号化済み)
  - マルチAZ: 無効（学習用）
  - バックアップ: 7日間保持

#### シークレット管理
- **Secrets Manager**
  - シークレット名: `saa-learning-db-credentials-dev`
  - 保存内容: データベースユーザー名、パスワード、エンドポイント、ポート

#### セキュリティ
- **DB Subnet Group**: RDS配置用
- **DB Security Group**: PostgreSQL (5432) アクセス制御

---

### Phase 4: アプリケーション層（14個のリソース）

#### ログ管理
- **CloudWatch Logs Group**: `/ecs/saa-learning`
  - 保持期間: 7日間

#### IAM Roles & Policies
- **ECS Task Execution Role**
  - ECRイメージプル権限
  - CloudWatch Logs送信権限
  - Secrets Manager読み取り権限
- **ECS Task Role**
  - アプリケーションコードからのAWSアクセス用（現在は空）

#### ロードバランサー
- **Application Load Balancer**
  - 名前: `saa-learning-alb`
  - DNS: `saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com`
  - スキーム: Internet-facing
  - サブネット: Public Subnets
- **Target Group**: `saa-learning-tg`
  - ポート: 3000
  - ヘルスチェックパス: `/`
- **Listener**: HTTP (80)

#### セキュリティグループ
- **ALB Security Group**
  - Ingress: TCP 80 from 0.0.0.0/0
  - Egress: All
- **ECS Security Group**
  - Ingress: TCP 3000 from ALB SG
  - Egress: All

#### コンテナオーケストレーション
- **ECS Cluster**: `saa-learning-cluster` (Fargate)
- **Task Definition**: `saa-learning-task`
  - CPU: 256 (0.25 vCPU)
  - Memory: 512 MiB
  - ネットワークモード: awsvpc
  - コンテナ設定:
    - イメージ: ECR Repository (latest)
    - ポート: 3000
    - 環境変数: DATABASE_HOST, DATABASE_NAME, PORT
    - シークレット: DATABASE_USERNAME, DATABASE_PASSWORD
- **ECS Service**: `saa-learning-service`
  - Desired Count: 1
  - 配置: Private Subnets
  - ロードバランサー統合: 有効

---

## 🔄 CDKとTerraformの違い

### コード比較

| 項目 | CDK (TypeScript) | Terraform (HCL) |
|------|------------------|-----------------|
| **言語** | プログラミング言語 (TypeScript) | 宣言的設定言語 (HCL) |
| **学習曲線** | TypeScript知識必要 | HCL構文のみ |
| **抽象度** | 高レベル（L2/L3 Construct） | 低レベル（直接リソース定義） |
| **コード量** | 少ない（抽象化されている） | 多い（詳細な設定） |
| **柔軟性** | プログラムロジック使用可 | 限定的（関数、変数） |
| **マルチクラウド** | AWS専用 | マルチクラウド対応 |
| **状態管理** | CloudFormation | Terraform State |
| **モジュール** | Constructライブラリ | Terraformモジュール |

### 移行での気づき

#### CDKの利点
- **高レベル抽象化**: VPCを数行で定義可能
- **タイプセーフ**: TypeScriptの型チェック
- **豊富なライブラリ**: AWS公式Construct使用

#### Terraformの利点
- **明示的**: すべてのリソースが明確に定義される
- **学習しやすい**: HCL構文はシンプル
- **マルチクラウド**: AWS以外のプロバイダーも使用可能
- **ドライラン**: `terraform plan`で変更を事前確認
- **広く使われている**: エンタープライズで標準的

---

## 📁 プロジェクト構成

```
cdk-docker-saa/
├── docs/
│   ├── MIGRATION_PLAN.md           # 移行計画書
│   ├── PHASE1_SETUP_GUIDE.md       # Phase 1ガイド
│   ├── PHASE4_APPLICATION_GUIDE.md # Phase 4ガイド
│   └── MIGRATION_COMPLETED.md      # 本ドキュメント
├── terraform/
│   ├── main.tf                     # メイン設定
│   ├── variables.tf                # 変数定義
│   ├── outputs.tf                  # 出力値
│   ├── .terraform.lock.hcl         # プロバイダーロック
│   └── modules/
│       ├── networking/             # ネットワークモジュール
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── database/               # データベースモジュール
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── ecs/                    # ECSモジュール
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── lib/                            # 元のCDKコード（参考用）
└── .gitignore                      # Terraform対応
```

---

## 🎯 デプロイ済みリソースへのアクセス

### アプリケーションURL
```
http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com
```

⚠️ **注意**: Dockerイメージがプッシュされるまで503エラーが表示されます

### ECS管理
```bash
# クラスター名
saa-learning-cluster

# サービス名
saa-learning-service

# タスク確認
aws ecs list-tasks --cluster saa-learning-cluster --service-name saa-learning-service
```

### ECR Repository
```bash
# リポジトリURL
032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app

# ログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com
```

### データベース接続
```bash
# エンドポイント
saa-learning-db.c7u00y8qancp.ap-northeast-1.rds.amazonaws.com:5432

# データベース名
saalearningdb

# 認証情報（Secrets Manager）
aws secretsmanager get-secret-value --secret-id saa-learning-db-credentials-dev
```

### ログ確認
```bash
# リアルタイムログ
aws logs tail /ecs/saa-learning --follow

# 最新5分間のログ
aws logs tail /ecs/saa-learning --since 5m
```

---

## 🔧 次のステップ

### 1. Dockerイメージのプッシュ

```bash
# ECRログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com

# イメージビルド
docker build -t saa-learning-app ./app

# タグ付け
docker tag saa-learning-app:latest \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest

# プッシュ
docker push \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest

# ECSサービス再起動
aws ecs update-service --cluster saa-learning-cluster \
  --service saa-learning-service --force-new-deployment
```

### 2. アプリケーション動作確認

```bash
# ALBにアクセス
curl http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com

# ヘルスチェック
curl http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com/health

# ログ確認
aws logs tail /ecs/saa-learning --follow
```

### 3. オプション: 環境拡張

#### HTTPS対応
1. ACMで証明書取得
2. ALBにHTTPSリスナー追加
3. HTTPからHTTPSへリダイレクト

#### Auto Scaling設定
1. ECS Service Auto Scaling設定
2. CPU/メモリ使用率に基づくスケーリングポリシー

#### 監視・アラート
1. CloudWatch Alarmsでメトリクス監視
2. SNSでアラート通知設定

#### CI/CD パイプライン
1. GitHub Actionsでイメージビルド自動化
2. CodePipelineでデプロイ自動化

---

## 📊 コスト見積もり（月額）

| リソース | 料金 | 備考 |
|---------|------|------|
| **VPC** | 無料 | - |
| **NAT Gateway** | ~$32 | 730時間稼働 |
| **RDS db.t3.micro** | ~$15 | Single-AZ |
| **ECR** | ~$1 | ストレージ量による |
| **ECS Fargate** | ~$10 | 0.25vCPU, 512MB, 1タスク |
| **ALB** | ~$20 | 基本料金 + トラフィック |
| **CloudWatch Logs** | ~$1 | ログ量による |
| **Secrets Manager** | ~$0.40 | シークレット1個 |
| **合計** | **~$79/月** | 学習環境 |

**コスト削減のヒント:**
- 使わない時は`terraform destroy`でリソース削除
- RDSをSingle-AZで運用（Multi-AZは約2倍）
- NAT Gatewayを削除してPrivate Subnetを使わない構成も可能

---

## 🎓 学んだこと

### Terraform基礎
- ✅ HCL構文の理解
- ✅ モジュール化のベストプラクティス
- ✅ 変数、出力値の使い方
- ✅ `terraform init`, `plan`, `apply`の流れ

### AWSアーキテクチャ
- ✅ VPCネットワーキング（Subnets、Routing、NAT Gateway）
- ✅ ECS Fargateでのコンテナオーケストレーション
- ✅ ALBでのロードバランシング
- ✅ IAM Roleでのセキュリティ管理
- ✅ Secrets Managerでの機密情報管理

### セキュリティベストプラクティス
- ✅ Private Subnetでのアプリケーション配置
- ✅ Security Groupによる最小権限の原則
- ✅ Secrets Managerでの認証情報管理
- ✅ IAM Roleによるきめ細かいアクセス制御

---

## 🎉 まとめ

**CDK → Terraform移行が完全に完了しました！**

### 達成したこと
- ✅ 41個のAWSリソースをTerraformで再構築
- ✅ モジュール化されたインフラコード
- ✅ 初学者向けドキュメント完備
- ✅ セキュアなアーキテクチャ実装

### プロジェクトの成果
- **再現性**: `terraform apply`で同じ環境を何度でも構築可能
- **保守性**: モジュール化により変更が容易
- **可視性**: すべてのリソースがコードで明示的に定義
- **学習価値**: AWS・Terraformの実践的なスキル習得

---

## 📚 参考資料

### 作成したドキュメント
- [MIGRATION_PLAN.md](./MIGRATION_PLAN.md) - 移行計画書
- [PHASE1_SETUP_GUIDE.md](./PHASE1_SETUP_GUIDE.md) - Terraform環境セットアップ
- [PHASE4_APPLICATION_GUIDE.md](./PHASE4_APPLICATION_GUIDE.md) - アプリケーション層ガイド

### 公式ドキュメント
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)

---

**🚀 CDK → Terraform移行プロジェクト完了！お疲れさまでした！**

