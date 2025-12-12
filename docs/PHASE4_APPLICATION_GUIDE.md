# Phase 4: アプリケーション層の構築ガイド

## 📚 目次
1. [概要](#概要)
2. [作成したリソース](#作成したリソース)
3. [各リソースの役割](#各リソースの役割)
4. [デプロイ手順](#デプロイ手順)
5. [動作確認](#動作確認)
6. [トラブルシューティング](#トラブルシューティング)

---

## 📖 概要

Phase 4では、**アプリケーション層**を構築しました。これは、Dockerコンテナでアプリケーションを実行し、インターネットからアクセスできるようにするための層です。

### 🎯 Phase 4の目標

- ✅ Application Load Balancer（ALB）でインターネットからのトラフィックを受け付ける
- ✅ ECS Fargateでコンテナアプリケーションを実行
- ✅ IAM RoleでAWSリソースへのアクセス権限を管理
- ✅ CloudWatch Logsでアプリケーションのログを収集

---

## 🏗️ 作成したリソース

### 1. **CloudWatch Logs Group**
```
名前: /ecs/saa-learning
保持期間: 7日間
```

**役割**: ECSコンテナのログを保存する場所
- アプリケーションのエラーログ、アクセスログなどを記録
- `aws logs tail /ecs/saa-learning --follow` でリアルタイム確認可能

---

### 2. **IAM Role - ECS Task Execution Role**
```
名前: saa-learning-ecs-task-execution-role
ポリシー: AmazonECSTaskExecutionRolePolicy + Secrets Managerアクセス
```

**役割**: ECSがコンテナを起動するために必要な権限
- ECRからDockerイメージをプル
- CloudWatch Logsにログを送信
- Secrets Managerからデータベース認証情報を取得

**なぜ必要？**
ECS自身がAWSサービスにアクセスするために必要な権限です。アプリケーションコードからのアクセスではありません。

---

### 3. **IAM Role - ECS Task Role**
```
名前: saa-learning-ecs-task-role
```

**役割**: コンテナ内のアプリケーションがAWSサービスにアクセスするための権限
- 現在は空（必要に応じてポリシーを追加）
- 例: S3バケットへのアクセス、SQSキューへのアクセス等

**Execution RoleとTask Roleの違い**
- **Execution Role**: ECS自身が使う（イメージのプル、ログの送信）
- **Task Role**: アプリケーションコードが使う（S3、DynamoDB等へのアクセス）

---

### 4. **Security Group - ALB用**
```
名前: saa-learning-alb-sg
Ingress: TCP 80 from 0.0.0.0/0（インターネット全体）
Egress: すべて許可
```

**役割**: ALBへのアクセス制御
- インターネットからHTTP（80番ポート）でのアクセスを許可
- ALBからVPC内のすべてのリソースへのアウトバウンドを許可

---

### 5. **Security Group - ECS用**
```
名前: saa-learning-ecs-sg
Ingress: TCP 3000 from ALB Security Group
Egress: すべて許可
```

**役割**: ECSタスクへのアクセス制御
- ALBからのトラフィックのみ許可（セキュリティ強化）
- インターネットへの直接アクセスは不可（Private Subnetに配置）
- NAT Gateway経由でインターネットにアクセス可能

---

### 6. **Application Load Balancer（ALB）**
```
名前: saa-learning-alb
タイプ: Application Load Balancer
配置: Public Subnets（インターネット向け）
DNS名: saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com
```

**役割**: インターネットからのトラフィックを受け付け、ECSコンテナに転送
- HTTP（80番ポート）でリクエストを受信
- ヘルスチェックで正常なコンテナにのみトラフィックを送信
- 複数のコンテナにトラフィックを分散（ロードバランシング）

**なぜALBが必要？**
- ECSタスクはPrivate Subnetにあり、直接インターネットからアクセスできない
- ALBが公開エンドポイントとして機能
- SSL/TLS終端、ヘルスチェック、パスベースルーティング等の機能を提供

---

### 7. **Target Group**
```
名前: saa-learning-tg
ポート: 3000
プロトコル: HTTP
ターゲットタイプ: IP（Fargate用）
ヘルスチェックパス: /
```

**役割**: ALBがトラフィックを転送する先の定義
- ECSタスクのIPアドレスを自動登録
- ヘルスチェックで正常性を確認（30秒ごと）
- 正常: 200 OK を返すコンテナ
- 異常: 2回連続で失敗したコンテナは除外

---

### 8. **Listener**
```
ポート: 80
プロトコル: HTTP
デフォルトアクション: Target Groupに転送
```

**役割**: ALBへのリクエストをどう処理するかを定義
- 80番ポートでリクエストを待ち受け
- すべてのリクエストをTarget Groupに転送
- 将来的にパスベースルーティング（/api → API用TG、/ → Web用TG）も可能

---

### 9. **ECS Cluster**
```
名前: saa-learning-cluster
タイプ: Fargate
```

**役割**: ECSタスクを管理する論理的なグループ
- コンテナの実行環境を提供
- Fargateを使うことでサーバー管理不要（EC2インスタンスの管理不要）

**FargateとEC2の違い**
- **Fargate**: サーバーレス（AWSがサーバー管理）、簡単、コストは若干高め
- **EC2**: 自分でEC2インスタンスを管理、細かい制御可能、大規模運用でコスト削減可能

---

### 10. **ECS Task Definition**
```
ファミリー: saa-learning-task
CPU: 256（0.25 vCPU）
メモリ: 512 MiB
ネットワークモード: awsvpc（Fargate必須）
```

**役割**: コンテナの実行設定を定義（Dockerfileのようなもの）

**コンテナ設定:**
- **イメージ**: `032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest`
- **ポート**: 3000
- **環境変数**:
  - `DATABASE_HOST`: RDSのエンドポイント
  - `DATABASE_NAME`: データベース名
  - `PORT`: 3000
- **シークレット**（Secrets Managerから取得）:
  - `DATABASE_USERNAME`
  - `DATABASE_PASSWORD`
- **ログ**: CloudWatch Logs `/ecs/saa-learning` に送信

**重要ポイント:**
- 環境変数は平文、機密情報はSecretsで管理
- Secretsはコンテナ起動時にECSが自動的に注入

---

### 11. **ECS Service**
```
名前: saa-learning-service
Desired Count: 1（常に1つのタスクを実行）
起動タイプ: Fargate
配置: Private Subnets
```

**役割**: ECSタスクを継続的に実行・管理
- Desired Countの数だけタスクを維持
- タスクが停止したら自動的に再起動
- ALBのTarget Groupにタスクを自動登録
- ローリングアップデート（新バージョンデプロイ時に古いタスクを段階的に置き換え）

**Desired Count = 1 の意味:**
- 常に1つのタスクが実行されている
- タスクが異常終了したら、ECSが自動的に新しいタスクを起動
- 高可用性のためには2以上を推奨（本番環境）

---

## 🚀 デプロイ手順

### Step 1: Terraform設定の確認

```bash
cd terraform
terraform validate
```

### Step 2: 実行計画の確認

```bash
terraform plan
```

**期待される出力:**
- 14個のリソースが作成される
- ALB、ECS、IAM、Security Group等

### Step 3: デプロイ実行

```bash
terraform apply
```

- `yes` と入力して実行
- 約5-10分で完了

### Step 4: 出力情報の確認

```bash
terraform output
```

**重要な出力:**
- `load_balancer_dns_name`: ALBのURL
- `ecs_cluster_name`: ECSクラスター名
- `ecr_repository_url`: ECRリポジトリURL

---

## ✅ 動作確認

### 1. ECSタスクの状態確認

```bash
# タスク一覧
aws ecs list-tasks --cluster saa-learning-cluster --service-name saa-learning-service

# タスク詳細
aws ecs describe-tasks --cluster saa-learning-cluster --tasks <TASK_ID> \
  --query 'tasks[0].{status:lastStatus,health:healthStatus,containers:containers[*].{name:name,status:lastStatus}}'
```

**期待される状態:**
- `lastStatus`: RUNNING
- `healthStatus`: HEALTHY

### 2. ALBのヘルスチェック確認

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names saa-learning-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
```

**期待される状態:**
- `State`: healthy

### 3. ブラウザでアクセス

```
http://saa-learning-alb-764478167.ap-northeast-1.elb.amazonaws.com
```

**現在の状態:**
- ⚠️ Dockerイメージがプッシュされていない場合、503エラー
- ✅ イメージがプッシュされている場合、アプリケーションが表示される

### 4. ログの確認

```bash
# リアルタイムでログを確認
aws logs tail /ecs/saa-learning --follow

# 最新100行を確認
aws logs tail /ecs/saa-learning --since 5m
```

---

## 🐛 トラブルシューティング

### 問題1: ECSタスクが起動しない（PENDING状態）

**原因:**
- ECRにDockerイメージがない
- IAM権限不足

**解決策:**
```bash
# ECRリポジトリの確認
aws ecr describe-images --repository-name saa-learning-app

# イメージがない場合、プッシュが必要
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com

docker tag your-app:latest \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest

docker push \
  032710299553.dkr.ecr.ap-northeast-1.amazonaws.com/saa-learning-app:latest
```

---

### 問題2: ALBで503エラー

**原因:**
- Target Groupにhealthyなターゲットがない
- ECSタスクが起動していない
- ヘルスチェックパスが間違っている

**解決策:**
```bash
# Target Groupの状態確認
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# ヘルスチェックが失敗している場合
# 1. アプリケーションが `/` で200 OKを返すか確認
# 2. Security Groupでポート3000が開いているか確認
# 3. コンテナのログを確認
aws logs tail /ecs/saa-learning --follow
```

---

### 問題3: データベース接続エラー

**原因:**
- Security Groupでポート5432が開いていない
- 環境変数が正しく設定されていない
- Secrets Managerの権限不足

**解決策:**
```bash
# Security Groupの確認
aws ec2 describe-security-groups --group-ids <DB_SG_ID>

# Secrets Managerの値確認
aws secretsmanager get-secret-value --secret-id saa-learning-db-credentials-dev

# ECS Task Definitionの環境変数確認
aws ecs describe-task-definition --task-definition saa-learning-task \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

---

### 問題4: イメージプルエラー

**原因:**
- ECRへのアクセス権限がない
- イメージが存在しない

**解決策:**
```bash
# IAM Roleの確認
aws iam get-role --role-name saa-learning-ecs-task-execution-role

# ポリシーの確認
aws iam list-attached-role-policies --role-name saa-learning-ecs-task-execution-role

# ECRイメージの存在確認
aws ecr describe-images --repository-name saa-learning-app --image-ids imageTag=latest
```

---

## 📊 アーキテクチャ図

```
Internet
    |
    | HTTP (80)
    v
[Application Load Balancer]
    | (Public Subnet)
    |
    | Target Group (Port 3000)
    v
[ECS Fargate Task]
    | (Private Subnet)
    |
    +-- [Docker Container: App]
    |       |
    |       +-- Environment Variables
    |       +-- Secrets (from Secrets Manager)
    |       +-- Logs (to CloudWatch)
    |
    v
[RDS PostgreSQL]
    (Database Subnet)
```

---

## 🎓 学習ポイント

### 1. **コンテナオーケストレーション**
- ECSがコンテナのライフサイクルを管理
- 自動再起動、ヘルスチェック、スケーリング

### 2. **セキュリティのベストプラクティス**
- Private Subnetでコンテナを実行（直接インターネットアクセス不可）
- ALBで公開エンドポイントを提供
- Security Groupで最小権限の原則を適用
- Secrets Managerで機密情報を管理

### 3. **IAMの役割分担**
- Execution Role: インフラが使う権限
- Task Role: アプリケーションが使う権限

### 4. **ロードバランシング**
- ALBでトラフィック分散
- ヘルスチェックで正常なコンテナのみに転送
- 複数のAZに分散配置で高可用性

---

## 📚 次のステップ

1. **Dockerイメージのプッシュ**
   - アプリケーションをビルド
   - ECRにプッシュ
   - ECSサービスを更新

2. **Auto Scalingの設定**
   - CPU使用率に基づいて自動スケーリング
   - `desired_count`を動的に調整

3. **HTTPS対応**
   - ACMで証明書を取得
   - ALBにHTTPSリスナーを追加
   - HTTPからHTTPSへリダイレクト

4. **監視・アラート**
   - CloudWatch Alarmsでメトリクス監視
   - SNSでアラート通知
   - X-Rayで分散トレーシング

---

## 🎉 まとめ

Phase 4で、完全なコンテナアプリケーション環境が構築できました！

- ✅ インターネットからアクセス可能なALB
- ✅ セキュアなPrivate Subnetでのコンテナ実行
- ✅ 自動的なヘルスチェックと再起動
- ✅ CloudWatch Logsでのログ管理
- ✅ IAM Roleでのセキュアなアクセス制御

**CDK → Terraform移行完了！** 🚀

