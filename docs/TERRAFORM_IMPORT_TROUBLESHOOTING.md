# Terraform 1.5+ Import トラブルシューティング

## 📋 目次
- [実装中に遭遇した問題](#実装中に遭遇した問題)
- [重要な注意点](#重要な注意点)
- [よくある失敗パターン](#よくある失敗パターン)
- [ベストプラクティス](#ベストプラクティス)

---

## 🚨 実装中に遭遇した問題

### 問題1: ECS Cluster ARN形式エラー ⭐最も重要

#### **エラー内容**
```
Error: reading ECS Cluster (arn:aws:ecs:ap-northeast-1:032710299553:cluster/arn:aws:ecs:ap-northeast-1:032710299553:cluster/saa-learning-cluster): 
operation error ECS: DescribeClusters, https response error StatusCode: 400, 
RequestID: 83c79171-28c7-4b8b-b6d8-cbf8f3281127, 
InvalidParameterException: Unsupported resource type: cluster
```

#### **原因**
Import BlocksのID指定が**完全なARN**になっていた

```hcl
# ❌ 間違い: 完全なARN
import {
  to = aws_ecs_cluster.main
  id = "arn:aws:ecs:ap-northeast-1:032710299553:cluster/saa-learning-cluster"
}
```

#### **解決策**
ECS Clusterの場合は**クラスター名のみ**を指定

```hcl
# ✅ 正解: クラスター名のみ
import {
  to = aws_ecs_cluster.main
  id = "saa-learning-cluster"  # ARNではなくクラスター名
}
```

#### **学び**
リソースタイプによってID形式が異なる：

| リソース | ID形式 | 例 |
|---------|--------|-----|
| **VPC** | vpc-xxxxx | `vpc-09dcb16efba7fab4a` |
| **ECR Repository** | リポジトリ名 | `saa-learning-app` |
| **RDS Instance** | インスタンス識別子 | `saa-learning-db` |
| **ECS Cluster** | クラスター名 | `saa-learning-cluster` ⚠️ |
| **ALB** | 完全なARN | `arn:aws:elasticloadbalancing:...` |

**重要**: `aws ecs describe-clusters`コマンドの出力を確認すること！

---

### 問題2: ALB の subnet_mapping と subnets の競合

#### **エラー内容**
```
Error: Invalid combination of arguments
  with aws_lb.main,
  on generated.tf line 1:

"subnet_mapping": only one of `subnet_mapping,subnets` can be specified, 
but `subnet_mapping,subnets` were specified.
```

#### **原因**
自動生成されたコードに`subnets`と`subnet_mapping`の**両方**が含まれていた

```hcl
# ❌ 自動生成されたコード（エラー）
resource "aws_lb" "main" {
  subnets = ["subnet-0c85b71ee0eccda1c", "subnet-0dcac01c0d730810c"]
  
  subnet_mapping {
    subnet_id = "subnet-0c85b71ee0eccda1c"
  }
  subnet_mapping {
    subnet_id = "subnet-0dcac01c0d730810c"
  }
}
```

#### **解決策**
どちらか一方を削除する（通常は`subnets`のみで十分）

```hcl
# ✅ 修正後: subnetsのみ使用
resource "aws_lb" "main" {
  subnets = ["subnet-0c85b71ee0eccda1c", "subnet-0dcac01c0d730810c"]
  
  # subnet_mapping は削除
}
```

#### **学び**
- 自動生成コードは**そのまま使えない場合がある**
- `terraform validate`で構文チェック必須
- Elastic IPを使う場合のみ`subnet_mapping`が必要

---

### 問題3: VPC の IPv6 パラメータエラー

#### **エラー内容**
```
Error: Missing required argument
  with aws_vpc.main,
  on generated.tf line 12:

"ipv6_netmask_length": all of `ipv6_ipam_pool_id,ipv6_netmask_length` 
must be specified
```

#### **原因**
IPv6を使用していないのに`ipv6_netmask_length = 0`が生成された

```hcl
# ❌ 自動生成されたコード（エラー）
resource "aws_vpc" "main" {
  cidr_block          = "10.0.0.0/16"
  ipv6_netmask_length = 0  # 不要なパラメータ
}
```

#### **解決策**
IPv6関連パラメータを完全に削除

```hcl
# ✅ 修正後: IPv6パラメータ削除
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  # ipv6_netmask_length は削除
}
```

#### **学び**
- `null`や`0`でも「指定した」とみなされる
- 使わない機能のパラメータは**完全に削除**する

---

### 問題4: RDS の domain_dns_ips 最小値エラー

#### **エラー内容**
```
Error: Not enough list items
  with aws_db_instance.main,
  on generated.tf line 22:

Attribute domain_dns_ips requires 2 item minimum, 
but config has only 0 declared.
```

#### **原因**
Active Directoryドメイン統合を使用していないのに`domain_dns_ips = []`が生成された

```hcl
# ❌ 自動生成されたコード（エラー）
resource "aws_db_instance" "main" {
  identifier      = "saa-learning-db"
  domain_dns_ips  = []  # 空リストでもエラー
}
```

#### **解決策**
ドメイン関連パラメータを完全に削除

```hcl
# ✅ 修正後: ドメインパラメータ削除
resource "aws_db_instance" "main" {
  identifier = "saa-learning-db"
  # domain_dns_ips は削除
}
```

#### **学び**
- 空リスト`[]`でも検証エラーになる場合がある
- 未使用機能のパラメータは削除する

---

### 問題5: CloudFormation テンプレートに警告が混入

#### **問題**
`cdk synth`の出力に警告メッセージが含まれ、JSONとして不正

```bash
$ npx cdk synth > template.json

# 生成されたファイル:
[WARNING] aws-cdk-lib.aws_ecs.ClusterProps#containerInsights is deprecated.
Resources:
  SaaLearningVpc8829C2A7:
    Type: AWS::EC2::VPC
    ...
```

#### **原因**
標準エラー出力（stderr）が標準出力（stdout）にリダイレクトされた

#### **解決策1: stderrを破棄**
```bash
# ✅ 標準エラーを/dev/nullに
npx cdk synth 2>/dev/null > template.json
```

#### **解決策2: cdk.outから取得**
```bash
# ✅ cdk.outディレクトリから直接取得（推奨）
npx cdk synth
cp cdk.out/CdkDockerSaaStack.template.json template.json
```

#### **解決策3: --quietオプション**
```bash
# ✅ 警告を抑制
npx cdk synth --quiet > template.json
```

#### **学び**
- CLIツールの出力は常に**stderrとstdoutを分離**する
- パイプ処理では`2>/dev/null`を習慣化

---

### 問題6: cdk migrate は Terraform 非対応

#### **誤解**
AWS公式の`cdk migrate`ツールがTerraform生成に対応していると思った

```bash
# ❌ このコマンドは存在しない
npx cdk migrate --language terraform
```

#### **実際**
`cdk migrate`は**CloudFormation → CDK**のみ対応

```bash
# ✅ サポートされている言語
npx cdk migrate --language typescript  # TypeScript
npx cdk migrate --language python      # Python
npx cdk migrate --language java        # Java
npx cdk migrate --language go          # Go
npx cdk migrate --language csharp      # C#

# ❌ Terraform は非サポート
```

#### **エラー**
```
Invalid values:
  Argument: language, Given: "terraform", 
  Choices: "typescript", "ts", "go", "java", "python", "py", "csharp", "cs"
```

#### **解決策**
別のツールを使用：

| ツール | 用途 | コマンド |
|-------|------|---------|
| **Terraform Import** | 既存リソース → Terraform | `terraform plan -generate-config-out=` |
| **cf2tf** | CloudFormation → Terraform | `cf2tf template.json` |
| **former2** | AWS Console → Terraform | Web UI |

#### **学び**
- ツールの対応範囲を**公式ドキュメントで確認**する
- `cdk migrate`は**CDK専用**

---

## ⚠️ 重要な注意点

### 1. 生成コードは出発点、そのまま使えない

#### **理由**
- `null`パラメータが多数
- 競合するパラメータ（`subnets` vs `subnet_mapping`）
- 不要なパラメータ（IPv6、ドメイン統合等）

#### **必須作業**
```hcl
# ❌ 自動生成（冗長）
resource "aws_db_instance" "main" {
  allocated_storage       = 20
  allow_major_version_upgrade = null  # 不要
  apply_immediately       = null      # 不要
  character_set_name      = null      # 不要
  domain                  = null      # 不要
  domain_dns_ips          = []        # エラー原因
  # ... 50パラメータ
}

# ✅ クリーンアップ後（必要最小限）
resource "aws_db_instance" "main" {
  allocated_storage       = 20
  instance_class          = "db.t3.micro"
  engine                  = "postgres"
  engine_version          = "15.15"
  # ... 必要なパラメータのみ
}
```

---

### 2. リソースIDの形式を確認する

#### **必須手順**
```bash
# 1. AWS CLIで実際のIDを確認
aws ecs describe-clusters --clusters saa-learning-cluster

# 出力例:
{
  "clusters": [{
    "clusterArn": "arn:aws:ecs:ap-northeast-1:032710299553:cluster/saa-learning-cluster",
    "clusterName": "saa-learning-cluster"  # ← これを使う
  }]
}

# 2. Terraform公式ドキュメントで確認
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster#import
```

#### **リソース別ID一覧**

| リソース | 取得コマンド | ID形式 |
|---------|-------------|--------|
| **VPC** | `aws ec2 describe-vpcs` | `vpc-xxxxx` |
| **Subnet** | `aws ec2 describe-subnets` | `subnet-xxxxx` |
| **Security Group** | `aws ec2 describe-security-groups` | `sg-xxxxx` |
| **ECR Repository** | `aws ecr describe-repositories` | リポジトリ名 |
| **RDS Instance** | `aws rds describe-db-instances` | DB識別子 |
| **ECS Cluster** | `aws ecs describe-clusters` | クラスター名 |
| **ECS Service** | `aws ecs describe-services` | `cluster/service` |
| **ALB** | `aws elbv2 describe-load-balancers` | 完全なARN |
| **Target Group** | `aws elbv2 describe-target-groups` | 完全なARN |
| **IAM Role** | `aws iam get-role` | ロール名 |

---

### 3. terraform validate と terraform plan は必須

#### **実行順序**
```bash
# Step 1: 構文チェック
terraform validate
# → 基本的な構文エラーを検出

# Step 2: 実行計画確認
terraform plan
# → リソース作成/変更/削除の計画を表示
# → API呼び出しで実際の状態を確認

# Step 3: コード生成（Import時）
terraform plan -generate-config-out=generated.tf
# → 既存リソースからコード生成
```

#### **典型的なエラー検出**
```bash
$ terraform validate
Error: Invalid combination of arguments
  with aws_lb.main,
  "subnet_mapping": only one of `subnet_mapping,subnets` can be specified

$ terraform plan
Error: reading ECS Cluster: operation error ECS: DescribeClusters
```

---

### 4. 機密情報の扱い

#### **問題**
自動生成コードに機密情報が**平文**で含まれる可能性

```hcl
# ⚠️ 危険: パスワードが平文
resource "aws_db_instance" "main" {
  username = "dbadmin"
  password = "ActualPassword123!"  # ← 機密情報が露出！
}
```

#### **解決策1: sensitive変数を使う**
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "main" {
  password = var.db_password
}
```

#### **解決策2: Secrets Managerを使う**
```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "saa-learning-db-credentials-dev"
}

resource "aws_db_instance" "main" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)["password"]
}
```

#### **解決策3: 生成後に即削除**
```hcl
# generated.tfから機密情報を削除
resource "aws_db_instance" "main" {
  username = "dbadmin"
  password = null  # ← 削除して変数化
}
```

---

### 5. State管理の重要性

#### **Import時の挙動**
```bash
# Import Blocksを実行すると...
terraform plan -generate-config-out=generated.tf

# 1. Terraform Stateに既存リソースが記録される
# 2. 以降は terraform apply でリソースを管理できる
# 3. State削除すると管理外になる（リソースは削除されない）
```

#### **注意点**
```bash
# ❌ 危険: Stateを削除するとリソース管理を失う
rm terraform.tfstate

# ✅ 安全: Stateのバックアップ
cp terraform.tfstate terraform.tfstate.backup

# ✅ 推奨: リモートバックエンド使用
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
```

---

## 🔄 よくある失敗パターン

### パターン1: 全リソースを一度にImportしようとする

#### **失敗例**
```hcl
# ❌ 30個のリソースを一度にImport
import { to = aws_vpc.main, id = "vpc-xxxxx" }
import { to = aws_subnet.public1, id = "subnet-xxxxx" }
import { to = aws_subnet.public2, id = "subnet-xxxxx" }
# ... 30個
```

**結果**: 1つのエラーで全体が失敗

#### **推奨アプローチ**
```hcl
# ✅ 段階的にImport（Phase別）

# Phase 1: ネットワーク基盤
import { to = aws_vpc.main, id = "vpc-xxxxx" }

# Phase 2: データベース層
import { to = aws_db_instance.main, id = "db-xxxxx" }

# Phase 3: アプリケーション層
import { to = aws_ecs_cluster.main, id = "cluster-name" }
```

---

### パターン2: 依存関係を無視する

#### **問題**
```hcl
# ❌ セキュリティグループより先にRDSをImport
import { to = aws_db_instance.main, id = "db-xxxxx" }
import { to = aws_security_group.db, id = "sg-xxxxx" }
```

**結果**: RDSが参照するSGが存在せずエラー

#### **推奨順序**
```
1. VPC
2. Subnets
3. Security Groups
4. RDS/EC2/etc（SGに依存）
5. ECS Service（RDSに依存）
```

---

### パターン3: 生成コードをそのままコミット

#### **問題**
```bash
# ❌ クリーンアップせずにコミット
git add generated.tf
git commit -m "Add infrastructure"
```

**結果**:
- 冗長なコード（`null`多数）
- 競合エラー
- 機密情報漏洩リスク

#### **推奨手順**
```bash
# 1. クリーンアップ
# - nullを削除
# - 競合パラメータ修正
# - 機密情報削除

# 2. 検証
terraform validate
terraform plan

# 3. コミット
git add main.tf variables.tf
git commit -m "feat: Import existing infrastructure"
```

---

## ✅ ベストプラクティス

### 1. Import前の準備

```bash
# ✅ チェックリスト

# 1. Terraformバージョン確認
terraform version  # >= 1.5.0

# 2. AWSアカウント確認
aws sts get-caller-identity

# 3. リソース一覧作成
cat > resource-list.txt << EOF
vpc-xxxxx
subnet-xxxxx
sg-xxxxx
EOF

# 4. バックアップ
aws ec2 describe-vpcs > backup/vpcs.json
aws rds describe-db-instances > backup/rds.json
```

---

### 2. Import実行

```bash
# ✅ 段階的実行

# Phase 1: 単一リソースでテスト
cat > test-import.tf << EOF
import {
  to = aws_vpc.main
  id = "vpc-xxxxx"
}
EOF

terraform plan -generate-config-out=test-generated.tf
# → 成功したら次へ

# Phase 2: リソース追加
# Phase 3: 全体実行
```

---

### 3. 生成コードのクリーンアップ

```bash
# ✅ クリーンアップスクリプト

# 1. nullを削除
sed -i '' '/= null$/d' generated.tf

# 2. 空リストを削除
sed -i '' '/= \[\]$/d' generated.tf

# 3. 手動レビュー（重要！）
vim generated.tf
```

---

### 4. 検証とテスト

```bash
# ✅ 検証手順

# 1. 構文チェック
terraform validate

# 2. フォーマット
terraform fmt

# 3. 実行計画（変更なしを確認）
terraform plan
# 期待結果: "No changes. Your infrastructure matches the configuration."

# 4. ドライラン
terraform apply -dry-run
```

---

### 5. ドキュメント化

```bash
# ✅ 作成すべきドキュメント

# 1. Import実行記録
cat > IMPORT_LOG.md << EOF
## Import実行記録
- 実行日時: 2024-12-15
- 対象リソース: VPC, RDS, ECS
- 発生したエラー: ECS Cluster ARN形式エラー
- 解決方法: クラスター名に変更
EOF

# 2. リソース一覧
terraform state list > RESOURCES.txt

# 3. 依存関係図
terraform graph | dot -Tpng > dependencies.png
```

---

## 📊 成功率を上げるコツ

### コツ1: 公式ドキュメント優先
```
Terraform Registry > ブログ記事 > Stack Overflow
```

### コツ2: エラーメッセージを丁寧に読む
```
Error: Invalid combination of arguments
  with aws_lb.main,
  on generated.tf line 1:

"subnet_mapping": only one of `subnet_mapping,subnets` can be specified
```
→ **どのファイルの何行目**が明記されている

### コツ3: 小さく始めて拡大
```
1リソース → 5リソース → 全リソース
```

### コツ4: State管理を確実に
```bash
# 必ずバックアップ
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)
```

### コツ5: チームで共有
```
# エラーと解決策をWikiに記録
# 次の担当者が同じ失敗をしないように
```

---

## 🎯 まとめ

### 詰まりやすいポイント TOP 5

| 順位 | 問題 | 解決時間 |
|------|------|---------|
| 🥇 | ECS Cluster ARN形式 | 30分 |
| 🥈 | ALB subnet競合 | 15分 |
| 🥉 | CloudFormation警告混入 | 10分 |
| 4位 | VPC IPv6パラメータ | 10分 |
| 5位 | RDS domain_dns_ips | 5分 |

### 回避策

1. ✅ **公式ドキュメント確認**: リソースのImport構文を事前確認
2. ✅ **段階的実行**: 1リソースずつテスト
3. ✅ **terraform validate**: 構文チェックを習慣化
4. ✅ **クリーンアップ**: 生成コードをそのまま使わない
5. ✅ **ドキュメント化**: エラーと解決策を記録

---

## 📚 参考資料

### 公式ドキュメント
- [Terraform Import](https://developer.hashicorp.com/terraform/cli/import)
- [Import Blocks](https://developer.hashicorp.com/terraform/language/import)
- [AWS Provider - Import](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/import)

### トラブルシューティング
- [Common Import Errors](https://developer.hashicorp.com/terraform/cli/import#common-errors)
- [AWS Resource ID Formats](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html)

---

**作成日**: 2024年12月15日  
**最終更新**: 2024年12月15日  
**対象バージョン**: Terraform 1.10.3, AWS Provider 5.100.0

