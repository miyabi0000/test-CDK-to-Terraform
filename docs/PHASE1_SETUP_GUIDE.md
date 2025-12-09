# 📘 フェーズ1: Terraform環境セットアップ完全ガイド

> **対象読者**: Terraform初学者、IaC未経験者  
> **所要時間**: 約30分  
> **完了日**: 2024年12月9日

---

## 📚 目次

1. [フェーズ1の概要](#1-フェーズ1の概要)
2. [用語解説](#2-用語解説)
3. [ステップバイステップガイド](#3-ステップバイステップガイド)
4. [作成したファイルの詳細解説](#4-作成したファイルの詳細解説)
5. [トラブルシューティング](#5-トラブルシューティング)
6. [次のステップ](#6-次のステップ)

---

## 1. フェーズ1の概要

### 1.1 このフェーズの目的

フェーズ1は、Terraformを使ってAWSリソースを作成するための**基盤を整える準備段階**です。

**例え話**:
- 家を建てる前に、工具を揃えて、設計図を準備するようなものです
- Terraformのインストール = 工具を揃える
- 設定ファイルの作成 = 設計図を準備する

### 1.2 このフェーズで達成すること

✅ Terraformのインストール  
✅ プロジェクトのディレクトリ構造作成  
✅ AWSプロバイダーの設定  
✅ 変数の定義（プロジェクト全体の設定値）  
✅ 出力値の定義（デプロイ後に表示する情報）  
✅ Terraformの初期化（プラグインのダウンロード）

### 1.3 なぜこのフェーズが重要か

**プロジェクト構造の良し悪しが、後の開発効率を大きく左右します**

- ✅ 適切な構造 → 保守しやすい、拡張しやすい
- ❌ 不適切な構造 → コードが複雑化、バグが増える

---

## 2. 用語解説

### 2.1 Terraform（テラフォーム）

> **Infrastructure as Code (IaC)** ツールの一つ

**何をするツールか**:
- コード（テキストファイル）でインフラ（サーバー、ネットワーク等）を定義
- コマンド一つでインフラを自動作成・変更・削除

**例え**:
```
手動の場合:
1. AWSコンソールにログイン
2. VPCを作成（10回クリック）
3. サブネットを作成（20回クリック）
4. ...（繰り返し）
→ 時間がかかる、ミスが起きやすい、再現が困難

Terraformの場合:
1. コードファイルを書く（1回）
2. terraform apply を実行
→ 自動で全部作成、何度でも再現可能
```

**公式サイト**: https://www.terraform.io/

---

### 2.2 HCL（HashiCorp Configuration Language）

> Terraformで使用される独自の設定言語

**特徴**:
- 人間が読みやすい構文
- プログラミング言語ではなく「設定言語」
- 「こうあるべき」という状態を記述（宣言的）

**例**:
```hcl
# VPCを定義
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "my-vpc"
  }
}
```

**読み方**:
- `resource` = リソースを定義するキーワード
- `"aws_vpc"` = リソースの種類（AWS VPC）
- `"main"` = このリソースの名前（自分で付ける）
- `cidr_block` = VPCのIPアドレス範囲
- `tags` = リソースに付けるタグ（ラベル）

---

### 2.3 プロバイダー（Provider）

> Terraformが特定のクラウドやサービスと連携するためのプラグイン

**なぜ必要か**:
- Terraform本体は汎用的なコア機能のみ
- AWS、Azure、GCP等は別々のプラグインとして提供
- 使うプロバイダーだけをダウンロード（効率的）

**主なプロバイダー**:
| プロバイダー | 対象サービス | 例 |
|------------|------------|-----|
| `hashicorp/aws` | AWS | VPC、EC2、RDS等 |
| `hashicorp/azurerm` | Azure | Virtual Network等 |
| `hashicorp/google` | GCP | Compute Engine等 |
| `hashicorp/kubernetes` | Kubernetes | Pod、Service等 |

**プロバイダーの設定例**:
```hcl
provider "aws" {
  region = "ap-northeast-1"  # 東京リージョン
}
```

---

### 2.4 モジュール（Module）

> Terraformコードの再利用可能な部品

**例え**:
- レゴブロック
- 一度作れば、何度でも使い回せる
- 複雑な構成をシンプルに扱える

**モジュールの構造**:
```
modules/
└── networking/          ← VPC関連のモジュール
    ├── main.tf         ← メインのリソース定義
    ├── variables.tf    ← 入力変数
    └── outputs.tf      ← 出力値
```

**モジュールの呼び出し**:
```hcl
module "networking" {
  source = "./modules/networking"
  
  vpc_cidr = "10.0.0.0/16"
}
```

---

### 2.5 terraform init（初期化コマンド）

> Terraformプロジェクトを使用可能な状態にする初期化コマンド

**何が起こるか**:
1. プロバイダープラグインのダウンロード
2. モジュールのダウンロード（もしあれば）
3. `.terraform`ディレクトリの作成
4. バックエンドの初期化（状態管理）

**実行タイミング**:
- プロジェクトの最初
- プロバイダーを追加・変更した時
- モジュールを追加・変更した時

---

### 2.6 .terraform.lock.hcl（ロックファイル）

> プロバイダーのバージョンを固定するファイル

**なぜ必要か**:
```
問題の例:
- 開発者Aさん: AWS Provider v5.50使用
- 開発者Bさん: AWS Provider v5.100使用
→ 動作が微妙に違う、バグの原因に

解決策:
- .terraform.lock.hclにバージョンを記録
- チーム全員が同じバージョンを使用
→ 一貫性が保たれる
```


**方法1: Homebrew（推奨）**

```bash
# HashiCorpの公式タップを追加
brew tap hashicorp/tap

# Terraformをインストール
brew install hashicorp/tap/terraform
```

**方法2: 直接ダウンロード（今回使用した方法）**

```bash
# 1. ダウンロード（Apple Silicon用）
cd /tmp
curl -O https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_darwin_arm64.zip

# 2. 解凍
unzip terraform_1.9.8_darwin_arm64.zip

# 3. ユーザーディレクトリにインストール
mkdir -p ~/bin
mv terraform ~/bin/
chmod +x ~/bin/terraform

# 4. PATHに追加
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**なぜ ~/bin にインストール？**
- ✅ sudo（管理者権限）が不要
- ✅ ユーザーごとに管理できる
- ✅ システムに影響を与えない

#### 3.1.3 インストール確認

```bash
terraform version
```

**期待される出力**:
```
Terraform v1.9.8
on darwin_arm64
```

✅ バージョンが表示されればインストール成功！

---

### ステップ2: プロジェクト構造の作成

#### 3.2.1 なぜこのステップが必要か

Terraformプロジェクトに適切なディレクトリ構造を作成することで：
- ✅ コードの整理整頓ができる
- ✅ 再利用可能なモジュールを作れる
- ✅ 環境（dev/staging/production）を分離できる

#### 3.2.2 ディレクトリ構造の設計

```
terraform/
├── main.tf                # メイン設定（プロバイダー、モジュール呼び出し）
├── variables.tf           # 変数定義
├── outputs.tf             # 出力値定義
├── terraform.tfvars       # 変数の値（オプション、gitignore推奨）
├── .terraform/            # プロバイダープラグイン（自動作成）
├── .terraform.lock.hcl    # プロバイダーのバージョンロック
├── modules/               # 再利用可能なモジュール
│   ├── networking/        # VPC、サブネット関連
│   ├── database/          # RDS関連
│   └── ecs/              # ECS、ALB関連
└── environments/          # 環境別の設定
    ├── dev/              # 開発環境
    ├── staging/          # ステージング環境
    └── production/       # 本番環境
```

#### 3.2.3 ディレクトリ作成コマンド

```bash
cd /Users/shimizumasaya/CDK習熟/cdk-docker-saa

# ディレクトリを作成
mkdir -p terraform/{modules/{networking,database,ecs},environments/dev}
```

**オプション解説**:
- `-p` = 親ディレクトリも同時に作成
- `{...}` = 複数のディレクトリを一度に作成（ブレース展開）

#### 3.2.4 作成結果の確認

```bash
tree terraform/
```

**出力**:
```
terraform/
├── environments
│   └── dev
└── modules
    ├── database
    ├── ecs
    └── networking

7 directories, 0 files
```

✅ 7つのディレクトリが作成されました！

---

### ステップ3: プロバイダー設定ファイルの作成

#### 3.3.1 なぜこのステップが必要か

**プロバイダー設定**は、Terraformに「どのクラウドを使うか」を教えるために必要です。

今回は**AWS**を使うので、AWSプロバイダーを設定します。

#### 3.3.2 ファイル: terraform/main.tf

```hcl
terraform {
  # Terraformのバージョン要件
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
  region = var.aws_region  # 使用するリージョン（変数から取得）

  # デフォルトタグ: すべてのリソースに自動的に付与される
  default_tags {
    tags = {
      Project     = "SAA-Learning"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
```

#### 3.3.3 重要なポイント

**1. バージョン指定の意味**

```hcl
version = "~> 5.0"
```

| 記法 | 意味 | 例 |
|------|------|-----|
| `= 5.0.0` | 完全一致 | 5.0.0のみ |
| `>= 5.0` | 以上 | 5.0, 5.1, 6.0, ... |
| `~> 5.0` | 悲観的バージョン制約 | 5.0以上、6.0未満 |
| `~> 5.0.1` | より厳密 | 5.0.1以上、5.1.0未満 |

**推奨**: `~> x.y` 形式（マイナーバージョンの更新は許可、メジャーバージョンは固定）

**2. default_tagsの威力**

```hcl
default_tags {
  tags = {
    Project = "SAA-Learning"
    ManagedBy = "Terraform"
  }
}
```

**効果**:
- 全リソースに自動でタグが付く
- 個別にタグを書く必要がない
- コスト管理が簡単（タグで絞り込める）

**例**:
```hcl
# VPCを作成
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# ↓ 実際にはこうなる（自動）
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Project     = "SAA-Learning"    # 自動追加
    ManagedBy   = "Terraform"       # 自動追加
    Environment = "dev"             # 自動追加
  }
}
```

---

### ステップ4: 変数定義ファイルの作成

#### 3.4.1 なぜこのステップが必要か

**変数**を使うことで：
- ✅ 同じコードを異なる設定で実行できる
- ✅ 機密情報を分離できる
- ✅ 環境（dev/staging/production）ごとに値を変えられる

**例**:
```hcl
# 変数を使わない場合
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"  # ハードコード
}

# 変数を使う場合
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr  # 変数から取得
}
```

#### 3.4.2 ファイル: terraform/variables.tf

```hcl
# 基本設定
variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"  # 東京
}

variable "environment" {
  description = "環境名"
  type        = string
  default     = "dev"
  
  # バリデーション（入力値のチェック）
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "環境名は dev, staging, production のいずれかである必要があります。"
  }
}

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "saa-learning"
}

# ネットワーク設定
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

# データベース設定
variable "database_instance_class" {
  description = "RDSインスタンスクラス"
  type        = string
  default     = "db.t3.micro"
}

# ECS設定
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
```

#### 3.4.3 変数の型

Terraformでサポートされる変数の型：

| 型 | 説明 | 例 |
|----|------|-----|
| `string` | 文字列 | `"ap-northeast-1"` |
| `number` | 数値 | `256` |
| `bool` | 真偽値 | `true`, `false` |
| `list(型)` | リスト | `["a", "b", "c"]` |
| `map(型)` | マップ | `{key = "value"}` |
| `object({...})` | オブジェクト | 複雑な構造 |

#### 3.4.4 変数の使い方

**1. デフォルト値を使う**
```bash
terraform apply  # default値が使われる
```

**2. コマンドラインで指定**
```bash
terraform apply -var="environment=production"
```

**3. ファイルで指定（terraform.tfvars）**
```hcl
# terraform.tfvars
environment = "production"
vpc_cidr    = "10.1.0.0/16"
```

```bash
terraform apply  # terraform.tfvarsが自動で読み込まれる
```

**4. 環境変数で指定**
```bash
export TF_VAR_environment=production
terraform apply
```

---

### ステップ5: 出力値定義ファイルの作成

#### 3.5.1 なぜこのステップが必要か

**出力値**は、`terraform apply`実行後に重要な情報を表示するために使います。

**例**:
- ALBのDNS名（アプリケーションのURL）
- RDSのエンドポイント（データベースの接続先）
- ECRのURL（Dockerイメージのプッシュ先）

#### 3.5.2 ファイル: terraform/outputs.tf

```hcl
# VPC情報
output "vpc_id" {
  description = "VPCのID"
  value       = try(module.networking.vpc_id, null)
}

# サブネット情報
output "public_subnet_ids" {
  description = "パブリックサブネットのIDリスト"
  value       = try(module.networking.public_subnet_ids, [])
}

# ALB情報
output "load_balancer_dns_name" {
  description = "ALBのDNS名"
  value       = try(module.ecs.alb_dns_name, null)
}

# アプリケーションURL
output "application_url" {
  description = "🚀 アプリケーションURL"
  value       = try("http://${module.ecs.alb_dns_name}", "まだ作成されていません")
}

# 次のステップガイド
output "next_steps" {
  description = "📋 次のステップ"
  value = <<-EOT
  
  ✅ Terraform apply が完了しました！
  
  次のステップ:
  1. アプリケーションにアクセス:
     ${try("http://${module.ecs.alb_dns_name}", "ALBがまだ作成されていません")}
  
  2. Dockerイメージをプッシュ:
     docker tag your-app:latest ${try(module.ecs.ecr_repository_url, "ECRがまだ作成されていません")}:latest
  
  EOT
}
```

#### 3.5.3 重要なポイント

**1. try()関数の使い方**

```hcl
value = try(module.networking.vpc_id, null)
```

**意味**:
- `module.networking.vpc_id`を取得試みる
- 失敗したら（モジュールがまだない等）、`null`を返す
- エラーにならない（段階的な構築が可能）

**2. sensitive属性**

```hcl
output "database_password" {
  value     = aws_db_instance.main.password
  sensitive = true  # 画面に表示されない
}
```

**効果**:
- `terraform apply`の出力で`<sensitive>`と表示される
- ログに記録されない（セキュリティ向上）

**3. ヒアドキュメント（<<-EOT ... EOT）**

```hcl
value = <<-EOT
  複数行の
  テキストを
  書ける
  EOT
```

---

### ステップ6: Terraform初期化

#### 3.6.1 なぜこのステップが必要か

`terraform init`は、Terraformプロジェクトを**使用可能な状態**にします。

**何が起こるか**:
1. プロバイダープラグインのダウンロード
2. `.terraform`ディレクトリの作成
3. `.terraform.lock.hcl`の作成
4. バックエンドの初期化

#### 3.6.2 実行コマンド

```bash
cd /Users/shimizumasaya/CDK習熟/cdk-docker-saa/terraform
terraform init
```

#### 3.6.3 実際の出力

```
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/random versions matching "~> 3.5"...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/random v3.7.2...
- Installed hashicorp/random v3.7.2 (signed by HashiCorp)
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

#### 3.6.4 何が作成されたか

```bash
ls -la terraform/
```

**出力**:
```
.terraform/              ← プロバイダープラグインが保存される
.terraform.lock.hcl      ← バージョンロックファイル
main.tf
variables.tf
outputs.tf
modules/
environments/
```

#### 3.6.5 .terraformディレクトリの中身

```bash
tree .terraform/
```

```
.terraform/
└── providers
    └── registry.terraform.io
        └── hashicorp
            ├── aws
            │   └── 5.100.0
            │       └── darwin_arm64
            │           └── terraform-provider-aws_v5.100.0_x5
            └── random
                └── 3.7.2
                    └── darwin_arm64
                        └── terraform-provider-random_v3.7.2_x5
```

**重要**: `.terraform/`は`.gitignore`に追加すべき（容量が大きい、再ダウンロード可能）

---

## 4. 作成したファイルの詳細解説

### 4.1 ファイル一覧

| ファイル | 役割 | 行数 | 重要度 |
|---------|------|------|--------|
| `main.tf` | プロバイダー設定、モジュール呼び出し | 50行 | ⭐⭐⭐ |
| `variables.tf` | 変数定義 | 220行 | ⭐⭐⭐ |
| `outputs.tf` | 出力値定義 | 160行 | ⭐⭐☆ |
| `.terraform.lock.hcl` | プロバイダーバージョンロック | 自動生成 | ⭐⭐⭐ |

### 4.2 main.tf - プロバイダー設定

**このファイルの役割**:
- Terraformのバージョン指定
- 使用するプロバイダーの宣言
- AWSリージョンの設定
- デフォルトタグの設定

**重要なセクション**:

```hcl
terraform {
  required_version = ">= 1.0"  # ①
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # ②
      version = "~> 5.0"         # ③
    }
  }
}

provider "aws" {
  region = var.aws_region  # ④
  
  default_tags {           # ⑤
    tags = {
      Project = "SAA-Learning"
    }
  }
}
```

**解説**:
1. Terraformのバージョン制約（1.0以上を要求）
2. プロバイダーの取得元（HashiCorpの公式レジストリ）
3. プロバイダーのバージョン制約（5.x系）
4. 変数からリージョンを取得（動的）
5. すべてのリソースに自動適用されるタグ

### 4.3 variables.tf - 変数定義

**このファイルの役割**:
- プロジェクト全体で使う変数を定義
- デフォルト値を設定
- バリデーションルールを定義

**変数の構成要素**:

```hcl
variable "変数名" {
  description = "説明"           # ① 変数の説明
  type        = 型               # ② データ型
  default     = デフォルト値      # ③ デフォルト値（オプション）
  
  validation {                  # ④ バリデーション（オプション）
    condition     = 条件式
    error_message = "エラーメッセージ"
  }
}
```

**実例**:

```hcl
variable "environment" {
  description = "環境名（dev/staging/production）"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "環境名は dev, staging, production のいずれかである必要があります。"
  }
}
```

**この変数の動作**:
- ✅ `environment = "dev"` → OK
- ✅ `environment = "production"` → OK
- ❌ `environment = "test"` → エラー（validation違反）

### 4.4 outputs.tf - 出力値定義

**このファイルの役割**:
- `terraform apply`後に表示する情報を定義
- 他のTerraformプロジェクトから参照可能な値を公開

**出力値の構成要素**:

```hcl
output "出力名" {
  description = "説明"        # ① 出力の説明
  value       = 値            # ② 実際の値
  sensitive   = true/false    # ③ 機密情報フラグ（オプション）
}
```

**実例**:

```hcl
output "application_url" {
  description = "アプリケーションURL"
  value       = "http://${module.ecs.alb_dns_name}"
}
```

**terraform apply後の表示**:
```
Outputs:

application_url = "http://my-alb-123456789.ap-northeast-1.elb.amazonaws.com"
```

### 4.5 .terraform.lock.hcl - ロックファイル

**このファイルの役割**:
- プロバイダーのバージョンを記録
- チーム全員が同じバージョンを使用することを保証

**ファイルの内容**:

```hcl
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.100.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:abc123...",  # チェックサム（改ざん検知）
    "h1:def456...",
  ]
}
```

**Git管理**: ✅ このファイルは必ずコミットすべき

---

## 5. トラブルシューティング

### 5.1 Terraformがインストールできない

**問題**: `brew install terraform`が失敗する

```
Error: Your Command Line Tools (CLT) does not support macOS 26.
```

**原因**: Xcode Command Line Toolsのバージョンが古い

**解決策1**: Command Line Toolsを更新
```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install
```

**解決策2**: 直接ダウンロード（このガイドで使用した方法）
```bash
# Apple Silicon用
curl -O https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_darwin_arm64.zip
unzip terraform_1.9.8_darwin_arm64.zip
mkdir -p ~/bin
mv terraform ~/bin/
chmod +x ~/bin/terraform
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

### 5.2 terraform initが失敗する

**問題1**: プロバイダーのダウンロードエラー

```
Error: Failed to query available provider packages
```

**原因**: ネットワーク接続の問題、またはプロキシ設定

**解決策**:
1. インターネット接続を確認
2. プロキシ設定を確認
3. VPN接続を確認

---

**問題2**: モジュールが見つからない

```
Error: Module not found
```

**原因**: モジュールのパスが間違っている

**解決策**:
```hcl
# 間違い
module "networking" {
  source = "modules/networking"  # 相対パスの./ が抜けている
}

# 正しい
module "networking" {
  source = "./modules/networking"  # ./ を付ける
}
```

---

### 5.3 terraform validateが失敗する

**問題**: 構文エラー

```
Error: Argument or block definition required
```

**原因**: HCLの構文が間違っている

**よくある間違い**:

```hcl
# 間違い1: クォートの不一致
resource "aws_vpc" "main {  # " が閉じていない
  cidr_block = "10.0.0.0/16"
}

# 間違い2: 括弧の不一致
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  # } が抜けている

# 間違い3: コンマの使用（HCLではコンマ不要）
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16",  # コンマは不要
}
```

**デバッグ方法**:
```bash
# フォーマットチェック
terraform fmt -check

# 構文チェック
terraform validate

# VSCodeのTerraform拡張機能を使う（推奨）
```

---

### 5.4 変数が認識されない

**問題**: 

```
Error: Reference to undeclared input variable
```

**原因**: 変数が定義されていない

**解決策**:

```hcl
# variables.tfで変数を定義
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# main.tfで使用
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr  # var.を付ける
}
```

---

## 6. 次のステップ

### 6.1 フェーズ2への準備

フェーズ1が完了したら、次はフェーズ2に進みます：

**フェーズ2: ネットワーク層の移行**
- VPCの作成
- サブネット（パブリック、プライベート、データベース）の作成
- インターネットゲートウェイの作成
- NATゲートウェイの作成
- ルートテーブルの設定

### 6.2 学習リソース

**公式ドキュメント**:
- [Terraform公式ドキュメント](https://www.terraform.io/docs)
- [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

**チュートリアル**:
- [HashiCorp Learn](https://learn.hashicorp.com/terraform)
- [Terraform入門（日本語）](https://qiita.com/tags/terraform)

**書籍**:
- "Terraform: Up & Running" by Yevgeniy Brikman

---

## 7. まとめ

### 7.1 このフェーズで学んだこと

✅ Terraformとは何か、なぜ使うのか  
✅ HCL（HashiCorp Configuration Language）の基本  
✅ プロバイダーとモジュールの概念  
✅ 変数と出力値の使い方  
✅ terraform initの役割  
✅ プロジェクト構造のベストプラクティス

### 7.2 作成したファイル

```
terraform/
├── main.tf                    # プロバイダー設定（50行）
├── variables.tf               # 変数定義（220行）
├── outputs.tf                 # 出力値定義（160行）
├── .terraform/                # プロバイダープラグイン
├── .terraform.lock.hcl        # バージョンロックファイル
└── modules/                   # モジュールディレクトリ（次フェーズで使用）
    ├── networking/
    ├── database/
    └── ecs/
```

### 7.3 重要なコマンド

| コマンド | 役割 | タイミング |
|---------|------|-----------|
| `terraform init` | 初期化 | 最初、プロバイダー/モジュール変更時 |
| `terraform validate` | 構文チェック | コード変更後 |
| `terraform fmt` | フォーマット | コード変更後 |
| `terraform plan` | 実行計画確認 | apply前 |
| `terraform apply` | 実際にリソース作成 | plan確認後 |
| `terraform destroy` | リソース削除 | クリーンアップ時 |

### 7.4 次回予告

**フェーズ2: ネットワーク層の移行**

次のフェーズでは、実際にAWSリソースを作成します！
- Networkingモジュールの作成（VPC、サブネット等）
- terraform planで実行計画を確認
- terraform applyで実際にデプロイ
- AWSコンソールで作成されたリソースを確認

お疲れ様でした！🎉

