# 📘 CDKからTerraformへの移行計画書

> **対象読者**: インフラストラクチャコード（IaC）の初学者  
> **最終更新**: 2025年12月9日  
> **ステータス**: 計画段階

---

## 📚 目次

1. [はじめに - なぜ移行するのか](#1-はじめに---なぜ移行するのか)
2. [基本用語集](#2-基本用語集)
3. [現在のCDK構成の分析](#3-現在のcdk構成の分析)
4. [CDKとTerraformの違い](#4-cdkとterraformの違い)
5. [移行アプローチ](#5-移行アプローチ)
6. [リソースごとの移行マッピング](#6-リソースごとの移行マッピング)
7. [移行ステップ](#7-移行ステップ)
8. [リスクと対策](#8-リスクと対策)
9. [成功基準](#9-成功基準)
10. [参考資料](#10-参考資料)

---

## 1. はじめに - なぜ移行するのか

### 1.1 移行の目的

CDK（AWS Cloud Development Kit）からTerraformへの移行を検討する理由：

| 観点 | CDK | Terraform | 備考 |
|------|-----|-----------|------|
| **マルチクラウド対応** | AWS専用 | AWS/Azure/GCP対応 | クラウドベンダーロックイン回避 |
| **学習曲線** | TypeScript等プログラミング言語 | HCL（宣言的な独自言語） | 用途により長短あり |
| **コミュニティ** | AWSエコシステム | より広範なエコシステム | プロバイダーが豊富 |
| **状態管理** | CloudFormation依存 | 独自の状態管理 | 柔軟なバックエンド選択 |

### 1.2 このドキュメントの使い方

- **初学者**: まず「基本用語集」を読んで、基本概念を理解してください
- **実装者**: 「移行ステップ」を順番に実行してください
- **レビュー担当**: 「リスクと対策」を確認してください

---

## 2. 基本用語集

### 2.1 IaC（Infrastructure as Code）関連用語

#### **IaC（Infrastructure as Code）**
> インフラストラクチャをコードで定義・管理する手法

**なぜ必要か**: 手動での設定は間違いが起きやすく、再現性がない。コードで管理することで、バージョン管理、自動化、再現性が実現できる。

**例**: 
- ❌ AWSコンソールで手動でVPCを作成
- ✅ コードファイルにVPCの設定を書いて、コマンド一つでVPCを作成

---

#### **CDK（AWS Cloud Development Kit）**
> AWSが提供する、プログラミング言語（TypeScript、Python等）でインフラを定義するツール

**特徴**:
- TypeScript、Python、Java、C#などのプログラミング言語が使える
- AWS専用（他のクラウドでは使えない）
- 最終的にCloudFormationテンプレートに変換される

**実際のコード例**:
```typescript
// CDKの例: TypeScriptでVPCを定義
const vpc = new ec2.Vpc(this, 'MyVpc', {
  maxAzs: 2,
  natGateways: 1
});
```

---

#### **Terraform**
> HashiCorpが提供する、HCL言語でインフラを定義するマルチクラウド対応のツール

**特徴**:
- HCL（HashiCorp Configuration Language）という独自言語を使用
- AWS、Azure、GCP、Kubernetesなど、様々なプラットフォームに対応
- 独自の状態管理機能を持つ

**実際のコード例**:
```hcl
# Terraformの例: HCLでVPCを定義
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "MyVpc"
  }
}
```

---

#### **CloudFormation**
> AWSネイティブのIaCサービス。JSON/YAMLでインフラを定義

**CDKとの関係**: CDKは最終的にCloudFormationテンプレートに変換されて実行される

```
CDKコード (TypeScript)
    ↓ (cdk synth)
CloudFormationテンプレート (JSON)
    ↓ (cdk deploy)
実際のAWSリソース
```

---

#### **HCL（HashiCorp Configuration Language）**
> Terraformで使用される宣言的な設定言語

**特徴**:
- 人間が読みやすい構文
- プログラミング言語ではなく「設定言語」
- 「こうあるべき」という状態を記述（宣言的）

---

### 2.2 インフラリソース関連用語

#### **VPC（Virtual Private Cloud）**
> AWS上に作成する仮想的なプライベートネットワーク空間

**例え**: あなた専用のマンション全体のようなもの

**構成要素**:
- **サブネット**: VPC内の部屋（ネットワークセグメント）
- **ルートテーブル**: 部屋間の通路（通信経路）
- **インターネットゲートウェイ**: マンションの玄関（インターネット接続）
- **NATゲートウェイ**: プライベートな部屋からインターネットへの出口

**実際の構成**:
```
VPC (10.0.0.0/16) ← マンション全体
├── パブリックサブネット (10.0.1.0/24) ← 玄関近くの部屋（外部からアクセス可）
├── プライベートサブネット (10.0.11.0/24) ← 内部の部屋（外部から直接アクセス不可）
└── データベースサブネット (10.0.21.0/24) ← 金庫室（完全隔離）
```

---

#### **サブネット（Subnet）**
> VPC内のネットワークセグメント。IPアドレスの範囲を定義

**種類**:
- **パブリックサブネット**: インターネットから直接アクセス可能
  - 用途: ロードバランサー、踏み台サーバー
- **プライベートサブネット**: インターネットへの出口あり、外部から入れない
  - 用途: アプリケーションサーバー
- **データベースサブネット**: 完全に隔離（入口も出口もない）
  - 用途: データベース

---

#### **ECR（Elastic Container Registry）**
> AWSが提供するDockerイメージを保存するための倉庫サービス

**例え**: Dockerイメージ専用のストレージ（写真をGoogle Photosに保存するようなイメージ）

**なぜ必要か**: 
- Dockerイメージをどこかに保存しておく必要がある
- ECSがイメージを取得する場所として使用

---

#### **ECS（Elastic Container Service）**
> AWSが提供するDockerコンテナを実行・管理するサービス

**構成要素**:
- **クラスター**: コンテナを実行する環境全体
- **サービス**: 複数のタスクをまとめて管理
- **タスク**: 実際に動くコンテナ（1つ以上）
- **タスク定義**: コンテナの設計図（どのイメージを使うか、メモリはいくつか等）

**階層構造**:
```
クラスター (saa-learning-cluster)
  └── サービス (saa-learning-service)
      ├── タスク1 (コンテナ実行中)
      └── タスク2 (コンテナ実行中)
```

---

#### **Fargate**
> ECSでコンテナを実行する方法の一つ。サーバーレス（サーバー管理不要）

**比較**:
- **EC2起動タイプ**: 自分でEC2インスタンスを管理してコンテナを実行
- **Fargate**: AWSがサーバーを管理、ユーザーはコンテナだけを考える（簡単）

---

#### **ALB（Application Load Balancer）**
> HTTPやHTTPSのトラフィックを複数のサーバーに分散するサービス

**なぜ必要か**:
- 複数のコンテナに負荷を分散
- ヘルスチェック（コンテナが正常か確認）
- HTTPSの終端処理

**動作イメージ**:
```
ユーザー1 ────┐
ユーザー2 ────┤
ユーザー3 ────┼──> ALB ──┬──> コンテナ1
ユーザー4 ────┤          ├──> コンテナ2
ユーザー5 ────┘          └──> コンテナ3
```

---

#### **RDS（Relational Database Service）**
> AWSが提供するマネージドデータベースサービス

**マネージド**とは:
- ✅ AWSがバックアップ、パッチ適用、障害対応を自動で行う
- ✅ ユーザーはSQLを書くだけ
- ❌ OSにログインしたり、データベースソフトをインストールする必要がない

**対応データベース**: PostgreSQL、MySQL、MariaDB、Oracle、SQL Server等

---

#### **Secrets Manager**
> パスワードやAPIキーなどの機密情報を安全に保存・管理するサービス

**なぜ必要か**:
- ❌ パスワードをコードに直接書くのは危険
- ✅ Secrets Managerに保存して、必要な時だけ取得

**例**:
```typescript
// ❌ 悪い例: パスワードをコードに書く
const password = "MyPassword123!";

// ✅ 良い例: Secrets Managerから取得
const password = await secretsManager.getSecretValue();
```

---

#### **IAM（Identity and Access Management）**
> AWSのアクセス権限を管理するサービス

**構成要素**:
- **ユーザー**: 人間のユーザー
- **ロール**: AWSサービスやアプリケーションに付与する権限
- **ポリシー**: 「何ができるか」を定義した権限設定

**例**:
```
ECSタスク（コンテナ）に「タスク実行ロール」を付与
  ↓
このロールに「Secrets Managerからパスワードを読み取る権限」を付与
  ↓
コンテナがSecrets Managerからパスワードを取得できる
```

---

#### **CloudWatch Logs**
> AWSのログを収集・保存・検索するサービス

**用途**:
- アプリケーションのログを記録
- エラーが起きた時の調査
- 監視・アラート

---

### 2.3 Terraform固有の用語

#### **Provider（プロバイダー）**
> Terraformが特定のクラウドやサービスと連携するためのプラグイン

**例**:
```hcl
# AWSプロバイダーの設定
provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}
```

**主なプロバイダー**:
- `aws`: AWS
- `azurerm`: Azure
- `google`: GCP
- `kubernetes`: Kubernetes

---

#### **Resource（リソース）**
> Terraformで作成・管理するインフラの構成要素

**構文**:
```hcl
resource "リソースタイプ" "リソース名" {
  設定項目1 = 値1
  設定項目2 = 値2
}
```

**例**:
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

---

#### **Data Source（データソース）**
> 既存のリソースの情報を参照する機能

**例**:
```hcl
# 既存のAMI（Amazon Machine Image）を検索
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

---

#### **Variable（変数）**
> Terraformコードで使用する変数。設定値を外部化できる

**例**:
```hcl
# 変数の定義
variable "environment" {
  description = "環境名（dev, staging, production）"
  type        = string
  default     = "dev"
}

# 変数の使用
resource "aws_vpc" "main" {
  tags = {
    Environment = var.environment
  }
}
```

---

#### **Output（出力値）**
> Terraformで作成したリソースの情報を出力する機能

**例**:
```hcl
# ALBのDNS名を出力
output "load_balancer_dns" {
  value       = aws_lb.main.dns_name
  description = "ALBのDNS名"
}
```

---

#### **State（状態）**
> Terraformが管理する「現在のインフラの状態」を記録したファイル

**重要**: 
- `terraform.tfstate`というファイルに保存される
- **非常に重要なファイル**。削除すると管理できなくなる
- チーム開発では、S3などのリモートストレージに保存する

---

#### **Backend（バックエンド）**
> 状態ファイルをどこに保存するかの設定

**種類**:
- **ローカル**: 手元のPCに保存（デフォルト）
- **S3**: AWS S3に保存（推奨、チーム開発向け）
- **Terraform Cloud**: HashiCorpのクラウドサービス

**例**:
```hcl
# S3バックエンドの設定
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "production/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
```

---

#### **Module（モジュール）**
> Terraformコードの再利用可能な部品

**例え**: レゴブロック。同じ構成を何度も使いたい時に便利

**例**:
```hcl
# VPCモジュールの使用
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr = "10.0.0.0/16"
  environment = "production"
}
```

---

## 3. 現在のCDK構成の分析

### 3.1 リソース一覧

現在のCDKスタックで作成されているリソース：

| # | リソース | CDKのクラス | 役割 | 移行難易度 |
|---|----------|-------------|------|-----------|
| 1 | VPC | `ec2.Vpc` | ネットワーク基盤 | ⭐⭐☆ 中 |
| 2 | ECRリポジトリ | `ecr.Repository` | Dockerイメージ保存 | ⭐☆☆ 簡単 |
| 3 | RDS PostgreSQL | `rds.DatabaseInstance` | データベース | ⭐⭐⭐ 難 |
| 4 | ECSクラスター | `ecs.Cluster` | コンテナ実行環境 | ⭐☆☆ 簡単 |
| 5 | ECS Fargateサービス | `ecsPatterns.ApplicationLoadBalancedFargateService` | コンテナ + ALB | ⭐⭐⭐ 難 |
| 6 | CloudWatch Logs | `logs.LogGroup` | ログ管理 | ⭐☆☆ 簡単 |
| 7 | IAMロール | `iam.PolicyStatement` | 権限管理 | ⭐⭐☆ 中 |

**難易度の理由**:
- **簡単**: 1つのリソースが1対1でTerraformに対応
- **中**: 複数の設定項目がある、またはネットワーク構成が複雑
- **難**: 複数のリソースが組み合わさっている（ALB + ECS等）

---

### 3.2 現在のネットワーク構成

```
VPC (10.0.0.0/16)
├── アベイラビリティゾーン1 (ap-northeast-1a)
│   ├── パブリックサブネット (10.0.0.0/24)
│   ├── プライベートサブネット (10.0.128.0/24)
│   └── データベースサブネット (10.0.256.0/24)
│
├── アベイラビリティゾーン2 (ap-northeast-1c)
│   ├── パブリックサブネット (10.0.1.0/24)
│   ├── プライベートサブネット (10.0.129.0/24)
│   └── データベースサブネット (10.0.257.0/24)
│
├── インターネットゲートウェイ (パブリックサブネット用)
└── NATゲートウェイ x1 (プライベートサブネットの外部通信用)
```

**重要な設定**:
- **AZ数**: 2つ（高可用性のため）
- **NATゲートウェイ**: 1つ（コスト削減）
- **サブネットマスク**: /24（各サブネットで254個のIPアドレス）

---

### 3.3 現在のコンテナ構成

```
ECSクラスター: saa-learning-cluster
└── サービス: saa-learning-service
    ├── タスク定義
    │   ├── イメージ: ECRリポジトリ/latest
    │   ├── CPU: 256
    │   ├── メモリ: 512MB
    │   ├── ポート: 8080
    │   ├── 環境変数:
    │   │   - NODE_ENV=production
    │   │   - DATABASE_HOST=(RDSエンドポイント)
    │   │   - DATABASE_PORT=5432
    │   │   - DATABASE_NAME=saalearningdb
    │   └── シークレット:
    │       - DATABASE_USER (Secrets Managerから)
    │       - DATABASE_PASSWORD (Secrets Managerから)
    │
    ├── 希望タスク数: 2
    └── Application Load Balancer
        ├── リスナー: ポート80 (HTTP)
        └── ターゲットグループ: ECSタスク
```

---

### 3.4 現在のデータベース構成

```
RDS PostgreSQL
├── エンジン: PostgreSQL 15.4
├── インスタンスタイプ: t3.micro
├── ストレージ: 20GB (自動スケーリング有効)
├── マルチAZ: 無効（コスト削減）
├── データベース名: saalearningdb
├── 認証情報: Secrets Managerで自動生成
├── バックアップ: 7日間保持
└── セキュリティグループ:
    - VPC内からのポート5432を許可
    - ECSタスクからのアクセスを許可
```

---

### 3.5 CDKコードの依存関係図

```
VPC (最初に作成)
 ↓
├─→ RDSサブネットグループ
│    ↓
│   RDSインスタンス
│    ↓
│   Secrets Manager (自動作成)
│
├─→ ECSクラスター
│    ↓
│   CloudWatch Logsグループ
│    ↓
│   ECS Fargateサービス
│    ├─→ ALB
│    ├─→ タスク定義
│    └─→ IAMロール
│
└─→ ECRリポジトリ (独立)
```

**依存関係のポイント**:
1. VPCがないと他のリソースは作れない（最優先）
2. RDSの認証情報は自動生成される
3. ECS FargateサービスはALB、タスク定義、IAMロールを内包している

---

## 4. CDKとTerraformの違い

### 4.1 言語の違い

| 項目 | CDK | Terraform |
|------|-----|-----------|
| **言語** | TypeScript, Python, Java等 | HCL（独自言語） |
| **パラダイム** | 命令的（プログラミング） | 宣言的（設定） |
| **学習曲線** | プログラミング知識が必要 | HCLの構文を学ぶだけ |
| **柔軟性** | 高い（ループ、条件分岐が自由） | 中程度（制限あり） |

**コード比較例**:

```typescript
// CDK: TypeScript（命令的）
const subnets = [];
for (let i = 0; i < 3; i++) {
  subnets.push(new ec2.Subnet(this, `Subnet${i}`, {
    vpcId: vpc.id,
    cidrBlock: `10.0.${i}.0/24`
  }));
}
```

```hcl
# Terraform: HCL（宣言的）
resource "aws_subnet" "main" {
  count      = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.${count.index}.0/24"
}
```

---

### 4.2 抽象化レベルの違い

#### **CDKの高レベル抽象化**

CDKには「L1」「L2」「L3」の3つのレベルがあります：

```
L3（パターン）: ApplicationLoadBalancedFargateService
    ↓（自動的に作成）
L2（コンストラクト）: ALB, ECSService, TaskDefinition, SecurityGroup...
    ↓（自動的に作成）
L1（CloudFormation）: AWS::ElasticLoadBalancingV2::LoadBalancer...
```

**例**: `ApplicationLoadBalancedFargateService`は、1つのクラスで以下を全て作成：
- Application Load Balancer
- ターゲットグループ
- リスナー
- ECSサービス
- タスク定義
- セキュリティグループ
- IAMロール

#### **Terraformのリソース指向**

Terraformは基本的に「1リソース = 1定義」：

```hcl
# ALBは個別に定義
resource "aws_lb" "main" { ... }

# ターゲットグループも個別に定義
resource "aws_lb_target_group" "main" { ... }

# リスナーも個別に定義
resource "aws_lb_listener" "main" { ... }

# ECSサービスも個別に定義
resource "aws_ecs_service" "main" { ... }
```

**メリット**:
- ✅ 細かい制御が可能
- ✅ 分かりやすい（1リソース1定義）

**デメリット**:
- ❌ コード量が多くなる
- ❌ 依存関係を自分で管理する必要がある

---

### 4.3 状態管理の違い

| 項目 | CDK | Terraform |
|------|-----|-----------|
| **バックエンド** | CloudFormation | 独自の状態管理 |
| **状態ファイル** | CloudFormationスタック | terraform.tfstate |
| **状態の確認** | AWSコンソール | terraform show |
| **差分確認** | cdk diff | terraform plan |
| **ロールバック** | CloudFormationの機能 | 手動（git revert等） |

---

### 4.4 デプロイフローの違い

#### **CDKのデプロイフロー**

```
1. TypeScriptコードを書く (lib/stack.ts)
   ↓
2. ビルド (npm run build)
   TypeScript → JavaScript変換
   ↓
3. 合成 (cdk synth)
   CDKコード → CloudFormationテンプレート変換
   ↓
4. デプロイ (cdk deploy)
   CloudFormationテンプレート → AWS APIコール
   ↓
5. CloudFormationがリソース作成
```

#### **Terraformのデプロイフロー**

```
1. HCLコードを書く (main.tf)
   ↓
2. 初期化 (terraform init)
   プロバイダープラグインのダウンロード
   ↓
3. プラン作成 (terraform plan)
   差分を計算して実行計画を表示
   ↓
4. 適用 (terraform apply)
   直接AWS APIをコール
   ↓
5. 状態ファイル更新 (terraform.tfstate)
```

---

## 5. 移行アプローチ

### 5.1 移行戦略の選択

3つの移行戦略があります：

#### **戦略A: グリーンフィールド（推奨）**

既存環境を残したまま、新しい環境をTerraformで構築

```
[現在]               [移行中]              [移行後]
CDK環境    →    CDK環境 + Terraform環境    →    Terraform環境
(本番稼働)      (本番)    (テスト)              (本番稼働)
                                              CDK環境削除
```

**メリット**:
- ✅ リスクが低い（既存環境に影響なし）
- ✅ じっくりテストできる
- ✅ ロールバックが簡単

**デメリット**:
- ❌ 一時的にコストが2倍
- ❌ データ移行が必要

**推奨理由**: 学習目的、本番環境への影響を最小化したい場合

---

#### **戦略B: インプレース変換**

既存のCDK環境をTerraformにインポート

```
[現在]          [移行中]               [移行後]
CDK環境   →   CDK環境をTerraform化   →   Terraform環境
              (terraform import)
```

**メリット**:
- ✅ コストが増えない
- ✅ データ移行不要

**デメリット**:
- ❌ リスクが高い（本番環境を直接変更）
- ❌ terraform importが複雑
- ❌ ロールバックが困難

**推奨理由**: コスト制約が厳しい場合

---

#### **戦略C: ブルー/グリーンデプロイメント**

新旧環境を並行稼働させて、徐々に切り替え

```
[現在]              [移行中]                    [移行後]
CDK環境     →    CDK環境(100%) + Terraform環境    →    Terraform環境(100%)
(100%)           ↓ 徐々に切り替え                    CDK環境削除
                CDK環境(50%) + Terraform環境(50%)
                ↓
                CDK環境(0%) + Terraform環境(100%)
```

**メリット**:
- ✅ 段階的な切り替えが可能
- ✅ 問題があればすぐにロールバック

**デメリット**:
- ❌ 複雑な切り替えロジックが必要
- ❌ データ同期が必要

**推奨理由**: 大規模な本番環境

---

### 5.2 このプロジェクトでの推奨戦略

**戦略A: グリーンフィールド** を推奨します。

**理由**:
1. 学習用プロジェクトなので、リスクを取る必要がない
2. CDK環境を残しておくことで、比較しながら学習できる
3. 何か問題があっても、CDK環境に戻れる

---

### 5.3 移行の段階分け

移行を4つのフェーズに分けます：

```
フェーズ1: 準備
  - Terraform環境のセットアップ
  - 基本的なファイル構成の作成
  - バックエンド設定（状態管理）

フェーズ2: ネットワーク層の移行
  - VPC
  - サブネット
  - インターネットゲートウェイ
  - NATゲートウェイ
  - ルートテーブル
  - セキュリティグループ

フェーズ3: データ層の移行
  - ECRリポジトリ
  - RDS PostgreSQL
  - Secrets Manager

フェーズ4: アプリケーション層の移行
  - ECSクラスター
  - タスク定義
  - ECSサービス
  - Application Load Balancer
  - IAMロール
  - CloudWatch Logs
```

---

## 6. リソースごとの移行マッピング

### 6.1 VPC（ネットワーク基盤）

#### **CDKコード**

```typescript
const vpc = new ec2.Vpc(this, 'SaaLearningVpc', {
  maxAzs: 2,
  natGateways: 1,
  subnetConfiguration: [
    {
      cidrMask: 24,
      name: 'Public',
      subnetType: ec2.SubnetType.PUBLIC,
    },
    {
      cidrMask: 24,
      name: 'Private',
      subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
    },
    {
      cidrMask: 24,
      name: 'Database',
      subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
    },
  ],
});
```

#### **Terraformコード**

```hcl
# VPC本体
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "saa-learning-vpc"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "saa-learning-igw"
  }
}

# パブリックサブネット（AZ1）
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "saa-learning-public-1"
  }
}

# パブリックサブネット（AZ2）
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "saa-learning-public-2"
  }
}

# プライベートサブネット（AZ1）
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.128.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "saa-learning-private-1"
  }
}

# プライベートサブネット（AZ2）
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.129.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "saa-learning-private-2"
  }
}

# データベースサブネット（AZ1）
resource "aws_subnet" "database_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.256.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "saa-learning-database-1"
  }
}

# データベースサブネット（AZ2）
resource "aws_subnet" "database_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.257.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "saa-learning-database-2"
  }
}

# NATゲートウェイ用のElastic IP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "saa-learning-nat-eip"
  }
}

# NATゲートウェイ
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "saa-learning-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "saa-learning-public-rt"
  }
}

# プライベートルートテーブル
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "saa-learning-private-rt"
  }
}

# データベースルートテーブル（ルートなし）
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "saa-learning-database-rt"
  }
}

# ルートテーブルの関連付け
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database_1" {
  subnet_id      = aws_subnet.database_1.id
  route_table_id = aws_route_table.database.id
}

resource "aws_route_table_association" "database_2" {
  subnet_id      = aws_subnet.database_2.id
  route_table_id = aws_route_table.database.id
}
```

#### **移行のポイント**

| CDK | Terraform | 注意点 |
|-----|-----------|--------|
| `maxAzs: 2` | 手動で2つのサブネットを定義 | TerraformではAZ数を明示的に指定 |
| `natGateways: 1` | `aws_nat_gateway` 1個 | Elastic IPも必要 |
| `subnetConfiguration` | 各サブネットを個別に定義 | CDKは自動、Terraformは手動 |

**コード量の違い**:
- CDK: 約20行
- Terraform: 約150行

**理由**: CDKは自動的に多くのリソースを作成するため

---

### 6.2 ECR（Dockerイメージリポジトリ）

#### **CDKコード**

```typescript
const ecrRepository = new ecr.Repository(this, 'DockerAppRepository', {
  repositoryName: 'saa-learning-app',
  imageScanOnPush: true,
  lifecycleRules: [
    {
      maxImageCount: 10,
    },
  ],
});
```

#### **Terraformコード**

```hcl
# ECRリポジトリ
resource "aws_ecr_repository" "main" {
  name                 = "saa-learning-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "saa-learning-app"
  }
}

# ライフサイクルポリシー
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

#### **移行のポイント**

- CDKの`lifecycleRules`はTerraformでは別リソース（`aws_ecr_lifecycle_policy`）
- ポリシーはJSON形式で記述

---

### 6.3 RDS（データベース）

#### **CDKコード**

```typescript
const database = new rds.DatabaseInstance(this, 'SaaLearningDatabase', {
  engine: rds.DatabaseInstanceEngine.postgres({
    version: rds.PostgresEngineVersion.VER_15_4,
  }),
  instanceType: ec2.InstanceType.of(
    ec2.InstanceClass.T3,
    ec2.InstanceSize.MICRO
  ),
  vpc,
  vpcSubnets: {
    subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
  },
  databaseName: 'saalearningdb',
  credentials: rds.Credentials.fromGeneratedSecret('dbadmin'),
  multiAz: false,
  deletionProtection: false,
  removalPolicy: cdk.RemovalPolicy.DESTROY,
});
```

#### **Terraformコード**

```hcl
# データベースサブネットグループ
resource "aws_db_subnet_group" "main" {
  name       = "saa-learning-db-subnet-group"
  subnet_ids = [
    aws_subnet.database_1.id,
    aws_subnet.database_2.id
  ]

  tags = {
    Name = "saa-learning-db-subnet-group"
  }
}

# データベース用セキュリティグループ
resource "aws_security_group" "database" {
  name        = "saa-learning-db-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "Allow PostgreSQL from ECS tasks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "saa-learning-db-sg"
  }
}

# ランダムなパスワード生成
resource "random_password" "database" {
  length  = 16
  special = true
}

# Secrets Managerにパスワードを保存
resource "aws_secretsmanager_secret" "database" {
  name = "saa-learning-db-credentials"

  tags = {
    Name = "saa-learning-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.database.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = "saalearningdb"
  })
}

# RDSインスタンス
resource "aws_db_instance" "main" {
  identifier     = "saa-learning-db"
  engine         = "postgres"
  engine_version = "15.4"

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "saalearningdb"
  username = "dbadmin"
  password = random_password.database.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  multi_az               = false
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = true
  backup_retention_period = 7

  tags = {
    Name = "saa-learning-db"
  }
}
```

#### **移行のポイント**

| CDK | Terraform | 注意点 |
|-----|-----------|--------|
| `Credentials.fromGeneratedSecret` | `random_password` + `aws_secretsmanager_secret` | Terraformは明示的に分離 |
| `vpcSubnets` | `aws_db_subnet_group` | 別リソースとして定義 |
| セキュリティグループ自動作成 | 手動で`aws_security_group`を作成 | 明示的な定義が必要 |

---

### 6.4 ECS + ALB（最も複雑）

#### **CDKコード**

```typescript
const fargateService = new ecsPatterns.ApplicationLoadBalancedFargateService(
  this,
  'DockerFargateService',
  {
    cluster,
    serviceName: 'saa-learning-service',
    taskImageOptions: {
      image: ecs.ContainerImage.fromEcrRepository(ecrRepository, 'latest'),
      containerPort: 8080,
      environment: {
        NODE_ENV: 'production',
        DATABASE_HOST: database.instanceEndpoint.hostname,
      },
      secrets: {
        DATABASE_PASSWORD: ecs.Secret.fromSecretsManager(database.secret!, 'password'),
      },
    },
    desiredCount: 2,
    publicLoadBalancer: true,
  }
);
```

#### **Terraformコード（長いため主要部分のみ）**

```hcl
# ECSクラスター
resource "aws_ecs_cluster" "main" {
  name = "saa-learning-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "saa-learning-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

# ターゲットグループ
resource "aws_lb_target_group" "main" {
  name        = "saa-learning-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# リスナー
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# タスク定義
resource "aws_ecs_task_definition" "main" {
  family                   = "saa-learning-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.main.repository_url}:latest"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "DATABASE_HOST"
          value = aws_db_instance.main.address
        }
      ]
      secrets = [
        {
          name      = "DATABASE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.database.arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = "ap-northeast-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECSサービス
resource "aws_ecs_service" "main" {
  name            = "saa-learning-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "app"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.main]
}
```

#### **移行のポイント**

| CDK | Terraform | 注意点 |
|-----|-----------|--------|
| 1つのクラス | 7つのリソース | ALB、TG、リスナー、サービス、タスク定義等 |
| 自動セキュリティグループ | 手動でSGを作成 | ALB用、ECSタスク用の2つ |
| 自動IAMロール | 手動でロールとポリシーを作成 | 実行ロール、タスクロール |

**コード量の違い**:
- CDK: 約30行
- Terraform: 約200行以上

---

## 7. 移行ステップ

### 7.1 フェーズ1: 準備（所要時間: 30分）

#### **ステップ1.1: Terraformのインストール**

```bash
# macOSの場合
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# インストール確認
terraform version
```

**期待される出力**:
```
Terraform v1.6.0
```

---

#### **ステップ1.2: プロジェクト構造の作成**

```bash
cd /Users/shimizumasaya/CDK習熟/cdk-docker-saa

# Terraformディレクトリを作成
mkdir -p terraform/{modules,environments/dev}

# ファイル構成
# terraform/
# ├── main.tf              # メインの設定ファイル
# ├── variables.tf         # 変数定義
# ├── outputs.tf           # 出力値
# ├── terraform.tfvars     # 変数の値（gitignore推奨）
# ├── backend.tf           # 状態管理の設定
# ├── modules/             # 再利用可能なモジュール
# │   ├── networking/      # VPC関連
# │   ├── database/        # RDS関連
# │   └── ecs/             # ECS + ALB関連
# └── environments/
#     └── dev/             # 開発環境用の設定
```

---

#### **ステップ1.3: プロバイダー設定**

`terraform/main.tf`を作成：

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "SAA-Learning"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
```

**解説**:
- `required_version`: Terraformのバージョン指定
- `required_providers`: 使用するプロバイダー（AWS、Random等）
- `default_tags`: 全リソースに自動的に付与されるタグ

---

#### **ステップ1.4: 変数定義**

`terraform/variables.tf`を作成：

```hcl
variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "環境名（dev, staging, production）"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "saa-learning"
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "database_instance_class" {
  description = "RDSインスタンスクラス"
  type        = string
  default     = "db.t3.micro"
}

variable "ecs_task_cpu" {
  description = "ECSタスクのCPU"
  type        = string
  default     = "256"
}

variable "ecs_task_memory" {
  description = "ECSタスクのメモリ（MB）"
  type        = string
  default     = "512"
}

variable "ecs_desired_count" {
  description = "ECSサービスの希望タスク数"
  type        = number
  default     = 2
}
```

---

#### **ステップ1.5: 状態管理の設定（S3バックエンド）**

`terraform/backend.tf`を作成：

```hcl
# 状態管理用のS3バケット（初回のみ作成）
# terraform/backend-setup.tf として別ファイルにするのが推奨
# 
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "saa-learning-terraform-state"
# }
#
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

terraform {
  backend "s3" {
    bucket = "saa-learning-terraform-state"
    key    = "dev/terraform.tfstate"
    region = "ap-northeast-1"
    
    # DynamoDBでロック管理（オプション）
    # dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**注意**: 最初は`backend "s3"`をコメントアウトし、ローカルで開始することを推奨

---

#### **ステップ1.6: 初期化**

```bash
cd terraform

# Terraformの初期化
terraform init

# フォーマット確認
terraform fmt -check

# 構文チェック
terraform validate
```

**期待される出力**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.30.0...

Terraform has been successfully initialized!
```

---

### 7.2 フェーズ2: ネットワーク層の移行（所要時間: 2時間）

#### **ステップ2.1: VPCモジュールの作成**

`terraform/modules/networking/main.tf`:

```hcl
# VPCの作成
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# インターネットゲートウェイ
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
    Type = "public"
  }
}

# プライベートサブネット
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 128)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
    Type = "private"
  }
}

# データベースサブネット
resource "aws_subnet" "database" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 256)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-database-${count.index + 1}"
    Type = "database"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"
  }
}

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# プライベートルートテーブル
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# データベースルートテーブル
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-database-rt"
  }
}

# ルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  count          = length(aws_subnet.database)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
```

`terraform/modules/networking/variables.tf`:

```hcl
variable "project_name" {
  description = "プロジェクト名"
  type        = string
}

variable "vpc_cidr" {
  description = "VPCのCIDRブロック"
  type        = string
}

variable "availability_zones" {
  description = "使用するアベイラビリティゾーン"
  type        = list(string)
}
```

`terraform/modules/networking/outputs.tf`:

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "プライベートサブネットのIDリスト"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "データベースサブネットのIDリスト"
  value       = aws_subnet.database[*].id
}

output "vpc_cidr_block" {
  description = "VPCのCIDRブロック"
  value       = aws_vpc.main.cidr_block
}
```

---

#### **ステップ2.2: メインファイルでモジュールを使用**

`terraform/main.tf`に追加:

```hcl
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}
```

---

#### **ステップ2.3: ネットワーク層のデプロイ**

```bash
# プラン確認
terraform plan

# 適用
terraform apply

# 確認
terraform show
```

**確認項目**:
- ✅ VPCが作成されている
- ✅ サブネットが6つ作成されている（パブリック x2、プライベート x2、データベース x2）
- ✅ インターネットゲートウェイが作成されている
- ✅ NATゲートウェイが作成されている
- ✅ ルートテーブルが正しく関連付けられている

---

### 7.3 フェーズ3: データ層の移行（所要時間: 2時間）

このフェーズでは、ECR、RDS、Secrets Managerを移行します。

詳細は、実際の移行時に段階的に作成します。

---

### 7.4 フェーズ4: アプリケーション層の移行（所要時間: 3時間）

このフェーズでは、ECS、ALB、IAM、CloudWatch Logsを移行します。

詳細は、実際の移行時に段階的に作成します。

---

## 8. リスクと対策

### 8.1 リスク一覧

| リスク | 影響度 | 発生確率 | 対策 |
|--------|--------|----------|------|
| **状態ファイルの紛失** | 高 | 中 | S3バックエンド + バージョニング |
| **リソースの重複作成** | 中 | 中 | グリーンフィールド戦略 |
| **ダウンタイム** | 高 | 低 | グリーンフィールドで並行稼働 |
| **コスト超過** | 中 | 中 | 移行後すぐにCDK環境を削除 |
| **設定ミス** | 中 | 高 | terraform planで事前確認 |
| **データ損失** | 高 | 低 | RDSスナップショット作成 |

---

### 8.2 具体的な対策

#### **対策1: 状態ファイルのバックアップ**

```bash
# ローカルの状態ファイルをバックアップ
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)

# S3にアップロード
aws s3 cp terraform.tfstate s3://my-backup-bucket/terraform-state-backup/
```

---

#### **対策2: RDSスナップショット**

```bash
# 手動スナップショット作成
aws rds create-db-snapshot \
  --db-instance-identifier saa-learning-db \
  --db-snapshot-identifier saa-learning-db-snapshot-$(date +%Y%m%d)
```

---

#### **対策3: ドライラン（terraform plan）**

```bash
# 実行計画を保存
terraform plan -out=tfplan

# 実行計画を確認
terraform show tfplan

# 問題なければ適用
terraform apply tfplan
```

---

## 9. 成功基準

### 9.1 技術的成功基準

- [ ] すべてのリソースがTerraformで作成できる
- [ ] CDK環境と同じ機能が動作する
- [ ] データベースへの接続が正常に動作する
- [ ] ALB経由でアプリケーションにアクセスできる
- [ ] ログがCloudWatch Logsに出力される
- [ ] `terraform destroy`でリソースを削除できる

---

### 9.2 学習目標の達成基準

- [ ] Terraformの基本構文（HCL）を理解している
- [ ] リソース、モジュール、変数、出力の使い方を理解している
- [ ] CDKとTerraformの違いを説明できる
- [ ] 状態管理の重要性を理解している
- [ ] セキュリティグループ、IAMロールをTerraformで定義できる

---

### 9.3 運用目標の達成基準

- [ ] チームメンバーがTerraformを使って変更を加えられる
- [ ] CIパイプラインでterraform planが実行される
- [ ] 環境（dev/staging/production）ごとに管理できる
- [ ] ドキュメントが整備されている

---

## 10. 参考資料

### 10.1 公式ドキュメント

- [Terraform公式ドキュメント](https://www.terraform.io/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CDK公式ドキュメント](https://docs.aws.amazon.com/cdk/latest/guide/home.html)

---

### 10.2 学習リソース

#### **初心者向け**
- [Terraform入門（HashiCorp Learn）](https://learn.hashicorp.com/collections/terraform/aws-get-started)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

#### **中級者向け**
- [Terraform Up & Running（書籍）](https://www.terraformupandrunning.com/)
- [Terraform Modules](https://www.terraform.io/docs/language/modules/index.html)

---

### 10.3 ツール

- **tfenv**: Terraformのバージョン管理ツール
- **tflint**: Terraformのリンター
- **terraform-docs**: ドキュメント自動生成ツール
- **checkov**: セキュリティスキャンツール

---

## 11. 次のステップ

移行完了後、以下のステップに進むことをお勧めします：

1. **CI/CDパイプラインの構築**
   - GitHub Actionsでterraform planを自動実行
   - プルリクエストで差分を確認

2. **環境分離**
   - dev/staging/production環境を分離
   - workspacesまたはディレクトリで管理

3. **モジュール化の推進**
   - 再利用可能なモジュールを作成
   - Terraform Registryに公開

4. **セキュリティ強化**
   - Secrets ManagerやParameter Storeの活用
   - IAMロールの最小権限化
   - セキュリティスキャン（checkov等）の導入

5. **コスト最適化**
   - Spot InstancesやSavings Plansの検討
   - 不要なリソースの自動削除

---

## 付録A: よくある質問（FAQ）

### Q1: CDKとTerraform、どちらを選ぶべきですか？

**A**: 以下の基準で選択してください：

- **CDKを選ぶ場合**:
  - AWS専用のプロジェクト
  - TypeScript/Python等のプログラミング言語に慣れている
  - 高レベルの抽象化が必要（ApplicationLoadBalancedFargateService等）

- **Terraformを選ぶ場合**:
  - マルチクラウド対応が必要
  - 宣言的な設定が好み
  - より広いコミュニティとエコシステムが必要

---

### Q2: Terraformの状態ファイルはどこに保存すべきですか？

**A**: 
- **学習・個人**: ローカル（デフォルト）
- **チーム開発**: S3 + DynamoDB（ロック機能）
- **エンタープライズ**: Terraform Cloud

---

### Q3: モジュールは必ず使うべきですか？

**A**: 
- **小規模プロジェクト**: なくても問題ない
- **中規模以上**: 推奨（再利用性、保守性向上）

---

### Q4: terraform importは使うべきですか？

**A**: 
- 既存環境をTerraformに移行する場合のみ
- 新規構築ではimportは不要
- importは複雑なので、可能ならグリーンフィールドで

---

## 付録B: トラブルシューティング

### エラー1: Error: Error creating VPC

```
Error: Error creating VPC: VpcLimitExceeded
```

**原因**: AWSアカウントのVPC制限に達している

**解決策**:
```bash
# 既存VPCの削除または制限緩和リクエスト
aws ec2 describe-vpcs
aws ec2 delete-vpc --vpc-id vpc-xxxxx
```

---

### エラー2: State lock error

```
Error: Error acquiring the state lock
```

**原因**: 別のterraformプロセスが実行中、または前回の実行が異常終了した

**解決策**:
```bash
# ロックを強制解除（注意: 実行中のプロセスがないことを確認）
terraform force-unlock <lock-id>
```

---

## まとめ

このドキュメントでは、CDKからTerraformへの移行計画を詳細に説明しました。

**重要なポイント**:
1. グリーンフィールド戦略でリスクを最小化
2. フェーズごとに段階的に移行
3. 状態ファイルの管理が最重要
4. terraform planで事前確認を徹底

**次のアクション**:
- [ ] Terraformのインストール
- [ ] フェーズ1（準備）の実行
- [ ] ネットワーク層の移行開始

移行作業、頑張ってください！🚀

