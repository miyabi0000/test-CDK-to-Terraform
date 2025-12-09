# CDK Docker プロジェクト

<!--
============================================
プロジェクトの概要とドキュメント
============================================

【構造】
このプロジェクトは以下の構成になっています:
- bin/: CDKアプリケーションのエントリーポイント
- lib/: CDKスタック定義（インフラ定義）
- docker-app/: Dockerアプリケーション（Node.js + Express + PostgreSQL）
- test/: テストファイル（現在は空）

【用途】
- AWS CDKでインフラを定義（Infrastructure as Code）
- DockerコンテナをECS Fargateで実行
- RDS PostgreSQLに接続するWebアプリケーション

【主要なファイル】
- bin/cdk-docker-saa.ts: CDKアプリのエントリーポイント
- lib/cdk-docker-saa-stack.ts: インフラ定義（VPC, ECR, RDS, ECS）
- docker-app/Dockerfile: Dockerイメージ定義
- docker-app/server.js: Node.jsアプリケーション
- package.json: プロジェクトの依存関係
- cdk.json: CDK設定ファイル
-->

AWS CDKを使用してDockerコンテナをECS Fargateで実行するインフラを構築するプロジェクトです。

## 📋 プロジェクト構成

```
cdk-docker-saa/
├── lib/
│   └── cdk-docker-saa-stack.ts  # CDKスタック定義
├── bin/
│   └── cdk-docker-saa.ts       # CDKアプリケーションエントリーポイント
├── docker-app/                  # Dockerアプリケーション
│   ├── Dockerfile
│   ├── server.js
│   └── package.json
├── README.md
├── DEPLOY_GUIDE.md             # デプロイガイド
├── TROUBLESHOOTING.md          # トラブルシューティング
└── ARCHITECTURE.md             # アーキテクチャ説明
```

## 🏗️ インフラ構成

このプロジェクトでは以下のAWSサービスを使用します：

1. **VPC** - ネットワーク基盤
   - パブリックサブネット（ALB用）
   - プライベートサブネット（ECSタスク用）
   - データベースサブネット（RDS用）

2. **ECR** - Dockerイメージリポジトリ

3. **ECS Fargate** - Dockerコンテナ実行環境
   - Application Load Balancer (ALB) と統合

4. **RDS PostgreSQL** - データベース
   - Secrets Managerで認証情報管理

5. **CloudWatch Logs** - ログ管理

## ⚡ クイックスタート

### 前提条件

- Node.js 18以上
- AWS CLIがインストール・設定済み
- Dockerがインストール・起動済み
- AWSアカウントと適切な権限

### セットアップ

```bash
# 依存関係のインストール
npm install

# TypeScriptのビルド
npm run build

# CDKのブートストラップ（初回のみ）
npx cdk bootstrap

# Dockerイメージをビルド（x86_64用）
cd docker-app
docker buildx build --platform linux/amd64 -t saa-learning-app:latest .
cd ..
```

### デプロイ

```bash
# デプロイ
npx cdk deploy --require-approval never

# デプロイ後、DockerイメージをECRにプッシュ
# ECR URIを取得
ECR_URI=$(aws cloudformation describe-stacks --stack-name CdkDockerSaaStack \
  --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
  --output text)

# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin $(echo $ECR_URI | cut -d'/' -f1)

# イメージにタグ付けしてプッシュ
docker tag saa-learning-app:latest $ECR_URI:latest
docker push $ECR_URI:latest

# ECS Serviceを更新
aws ecs update-service \
  --cluster saa-learning-cluster \
  --service saa-learning-service \
  --force-new-deployment
```

詳細は [DEPLOY_GUIDE.md](./DEPLOY_GUIDE.md) を参照してください。

## 📚 ドキュメント

- [DEPLOY_GUIDE.md](./DEPLOY_GUIDE.md) - デプロイ手順の詳細ガイド
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - よくある問題と解決方法
- [ARCHITECTURE.md](./ARCHITECTURE.md) - アーキテクチャの詳細説明
- [MECHANISM.md](./MECHANISM.md) - システムの仕組みの説明
- [HANDS_ON_GUIDE.md](./HANDS_ON_GUIDE.md) - 実践的な操作ガイド

## 🔧 開発

```bash
# TypeScriptのビルド
npm run build

# ウォッチモード（自動ビルド）
npm run watch

# CDKの合成（CloudFormationテンプレート生成）
npx cdk synth

# 差分確認
npx cdk diff

# デプロイ
npx cdk deploy
```

## 🗑️ 削除

```bash
# スタックを削除（リソースも削除される）
npx cdk destroy
```

## ⚠️ 重要な注意事項

### Dockerイメージのビルド

Mac（ARM64）で開発する場合、必ずx86_64用にビルドしてください：

```bash
docker buildx build --platform linux/amd64 -t saa-learning-app:latest .
```

AWS Fargateはx86_64アーキテクチャを使用するため、ARM64でビルドしたイメージは実行できません。

### package.jsonの依存関係

このプロジェクトはCDK v2を使用しています。`package.json`には`aws-cdk-lib`のみを含め、古いCDK v1パッケージ（`@aws-cdk/aws-*`）は使用しません。

## 📝 ライセンス

MIT
