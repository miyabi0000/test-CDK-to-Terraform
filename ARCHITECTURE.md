<!--
============================================
アーキテクチャ詳細説明ドキュメント
============================================

【構造】
このドキュメントは以下の内容を含みます:
- CDKライブラリの説明
- スタックの構造
- 各リソースの役割と設定
- ネットワーク構成
- セキュリティ設定

【用途】
- プロジェクトのアーキテクチャを理解するためのドキュメント
- 各CDKライブラリの使い方を説明
- インフラの設計思想を理解

【対象読者】
- プロジェクトの構造を理解したい開発者
- CDKライブラリの使い方を学びたい人
- インフラの設計を変更したい人
-->

# CDKプロジェクトのアーキテクチャ解説

このドキュメントでは、使用している各ライブラリ、スタック、そして全体の仕組みについて詳しく解説します。

## 📚 使用しているライブラリ一覧

### 1. **aws-cdk-lib** (コアライブラリ)
```typescript
import * as cdk from 'aws-cdk-lib';
```

**役割**: CDKのコア機能を提供
- `Stack`: CloudFormationスタックを表す基本クラス
- `App`: CDKアプリケーションのルート
- `CfnOutput`: CloudFormationの出力値を定義
- `Duration`, `RemovalPolicy` などのユーティリティ

**なぜ必要か**: すべてのCDKリソースの基盤となるライブラリ

---

### 2. **constructs**
```typescript
import { Construct } from 'constructs';
```

**役割**: Constructの基本型定義
- `Construct`: すべてのCDKリソースの基底クラス
- リソース間の親子関係を管理

**なぜ必要か**: TypeScriptの型安全性を提供

---

### 3. **aws-cdk-lib/aws-ec2** (VPC、ネットワーク)
```typescript
import * as ec2 from 'aws-cdk-lib/aws-ec2';
```

**提供するリソース**:
- `Vpc`: 仮想プライベートクラウド
- `SubnetType`: サブネットタイプ（PUBLIC, PRIVATE_WITH_EGRESS, PRIVATE_ISOLATED）
- `InstanceType`: EC2インスタンスタイプ
- `Peer`, `Port`: セキュリティグループの設定

**使用例**:
```typescript
const vpc = new ec2.Vpc(this, 'SaaLearningVpc', {
  maxAzs: 2,
  natGateways: 1,
  subnetConfiguration: [...]
});
```

**なぜ必要か**: ネットワーク基盤（VPC、サブネット、セキュリティグループ）を構築

---

### 4. **aws-cdk-lib/aws-ecr** (Dockerイメージリポジトリ)
```typescript
import * as ecr from 'aws-cdk-lib/aws-ecr';
```

**提供するリソース**:
- `Repository`: ECRリポジトリ（Dockerイメージを保存）

**使用例**:
```typescript
const ecrRepository = new ecr.Repository(this, 'DockerAppRepository', {
  repositoryName: 'saa-learning-app',
  imageScanOnPush: true,
  lifecycleRules: [...]
});
```

**なぜ必要か**: Dockerイメージを保存・管理する場所

---

### 5. **aws-cdk-lib/aws-ecs** (コンテナオーケストレーション)
```typescript
import * as ecs from 'aws-cdk-lib/aws-ecs';
```

**提供するリソース**:
- `Cluster`: ECSクラスター（コンテナを実行する環境）
- `ContainerImage`: コンテナイメージの参照
- `LogDrivers`: ログドライバー（CloudWatch Logsなど）
- `Secret`: Secrets Managerからのシークレット参照

**使用例**:
```typescript
const cluster = new ecs.Cluster(this, 'SaaLearningCluster', {
  vpc,
  containerInsights: true
});
```

**なぜ必要か**: Dockerコンテナを実行・管理するためのオーケストレーション

---

### 6. **aws-cdk-lib/aws-ecs-patterns** (ECSの高レベルパターン)
```typescript
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns';
```

**提供するリソース**:
- `ApplicationLoadBalancedFargateService`: ALB + ECS Fargateの統合パターン

**使用例**:
```typescript
const fargateService = new ecsPatterns.ApplicationLoadBalancedFargateService(
  this, 'DockerFargateService', {
    cluster,
    taskImageOptions: {...}
  }
);
```

**なぜ必要か**: ALBとECSを簡単に統合できる高レベルパターン（複数のリソースを自動的に作成）

---

### 7. **aws-cdk-lib/aws-rds** (リレーショナルデータベース)
```typescript
import * as rds from 'aws-cdk-lib/aws-rds';
```

**提供するリソース**:
- `DatabaseInstance`: RDSデータベースインスタンス
- `SubnetGroup`: データベース用サブネットグループ
- `DatabaseInstanceEngine`: データベースエンジン（PostgreSQL、MySQLなど）
- `Credentials`: データベース認証情報

**使用例**:
```typescript
const database = new rds.DatabaseInstance(this, 'SaaLearningDatabase', {
  engine: rds.DatabaseInstanceEngine.postgres({...}),
  instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
  // ...
});
```

**なぜ必要か**: マネージドデータベースサービス（PostgreSQL、MySQLなど）

---

### 8. **aws-cdk-lib/aws-iam** (アクセス制御)
```typescript
import * as iam from 'aws-cdk-lib/aws-iam';
```

**提供するリソース**:
- `PolicyStatement`: IAMポリシーステートメント
- `Effect`: ポリシーの効果（ALLOW/DENY）

**使用例**:
```typescript
new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  actions: ['secretsmanager:GetSecretValue'],
  resources: [database.secret!.secretArn]
});
```

**なぜ必要か**: AWSリソースへのアクセス権限を制御

---

### 9. **aws-cdk-lib/aws-logs** (ログ管理)
```typescript
import * as logs from 'aws-cdk-lib/aws-logs';
```

**提供するリソース**:
- `LogGroup`: CloudWatch Logsのロググループ
- `RetentionDays`: ログの保持期間

**使用例**:
```typescript
new logs.LogGroup(this, 'AppLogGroup', {
  logGroupName: '/ecs/saa-learning',
  retention: logs.RetentionDays.ONE_WEEK
});
```

**なぜ必要か**: アプリケーションログの収集・保存

---

## 🏗️ CDKの基本概念

### App（アプリケーション）
```typescript
const app = new cdk.App();
```
- CDKアプリケーションのルート
- 複数のスタックを含むことができる
- `bin/cdk-docker-saa.ts`で定義

### Stack（スタック）
```typescript
export class CdkDockerSaaStack extends cdk.Stack
```
- CloudFormationスタックに対応
- 関連するリソースをグループ化
- デプロイの単位

### Construct（コンストラクト）
- すべてのCDKリソースの基本単位
- 親子関係で階層的に構成
- 再利用可能なコンポーネント

**例**:
```
App
└── Stack (CdkDockerSaaStack)
    ├── Construct (VPC)
    │   ├── Construct (Public Subnet 1)
    │   ├── Construct (Public Subnet 2)
    │   └── ...
    ├── Construct (ECR Repository)
    ├── Construct (RDS Database)
    └── Construct (ECS Cluster)
        └── Construct (Fargate Service)
```

---

## 🔄 リソース間の関係とデータフロー

### 1. ネットワーク層（VPC）
```
VPC (10.0.0.0/16)
├── Public Subnets (ALB用)
│   ├── Subnet 1 (10.0.1.0/24) - AZ1
│   └── Subnet 2 (10.0.2.0/24) - AZ2
├── Private Subnets (ECS用)
│   ├── Subnet 1 (10.0.11.0/24) - AZ1
│   └── Subnet 2 (10.0.12.0/24) - AZ2
└── Database Subnets (RDS用)
    ├── Subnet 1 (10.0.21.0/24) - AZ1
    └── Subnet 2 (10.0.22.0/24) - AZ2
```

### 2. アプリケーション層（ECS + ALB）
```
Internet
  ↓
Application Load Balancer (パブリックサブネット)
  ↓
ECS Fargate Service (プライベートサブネット)
  ├── Task 1 (コンテナ)
  └── Task 2 (コンテナ)
```

### 3. データ層（RDS）
```
RDS PostgreSQL (データベースサブネット)
  └── Secrets Manager (認証情報)
```

### 4. データフロー
```
ユーザー
  ↓ HTTPリクエスト
ALB (パブリックサブネット)
  ↓ 内部通信
ECS Fargate Task (プライベートサブネット)
  ↓ データベース接続
RDS PostgreSQL (データベースサブネット)
```

---

## 🔐 セキュリティの仕組み

### 1. ネットワークセキュリティ
- **セキュリティグループ**: リソース間の通信を制御
  - ALB → ECS: ポート8080
  - ECS → RDS: ポート5432

### 2. IAMロール
- **タスク実行ロール**: ECSタスクがSecrets Managerから認証情報を取得
- **タスクロール**: アプリケーションがAWSサービスにアクセス

### 3. Secrets Manager
- データベースの認証情報を安全に管理
- 環境変数としてコンテナに注入

---

## 📦 デプロイの流れ

### 1. コードのコンパイル
```bash
npm run build
```
TypeScript → JavaScriptに変換

### 2. 合成（Synthesis）
```bash
npx cdk synth
```
CDKコード → CloudFormationテンプレートに変換

### 3. デプロイ
```bash
npx cdk deploy
```
CloudFormationテンプレートをAWSに送信してリソースを作成

### 4. リソース作成順序
1. VPC、サブネット、ルートテーブル
2. ECRリポジトリ
3. RDSデータベース
4. ECSクラスター
5. ALB、ターゲットグループ
6. ECSサービス、タスク定義

---

## 🎯 各リソースの役割まとめ

| リソース | ライブラリ | 役割 |
|---------|----------|------|
| VPC | `aws-ec2` | ネットワーク基盤 |
| ECR | `aws-ecr` | Dockerイメージ保存 |
| ECS Cluster | `aws-ecs` | コンテナ実行環境 |
| ECS Service | `aws-ecs-patterns` | コンテナの管理・スケーリング |
| ALB | `aws-ecs-patterns` | ロードバランシング |
| RDS | `aws-rds` | データベース |
| CloudWatch Logs | `aws-logs` | ログ収集 |
| IAM | `aws-iam` | アクセス制御 |

---

## 💡 重要なポイント

### 1. 高レベルパターンの活用
`ApplicationLoadBalancedFargateService`は、以下のリソースを自動的に作成：
- Application Load Balancer
- ターゲットグループ
- リスナー
- ECSサービス
- タスク定義

### 2. 依存関係の自動解決
CDKはリソース間の依存関係を自動的に解決：
```typescript
database.connections.allowFrom(
  fargateService.service,  // ECSサービスが先に作成される必要がある
  ec2.Port.tcp(5432)
);
```

### 3. 環境変数とシークレット
- **環境変数**: 通常の設定値（`environment`）
- **シークレット**: 機密情報（`secrets`）- Secrets Managerから取得

### 4. リソースの命名
各リソースには一意のIDが必要：
```typescript
new ec2.Vpc(this, 'SaaLearningVpc', {...})
//              ↑ このIDがリソース名の一部になる
```

---

## 🔍 トラブルシューティングのポイント

1. **依存関係エラー**: リソースの作成順序を確認
2. **セキュリティグループエラー**: ポートとソースを確認
3. **IAM権限エラー**: ポリシーステートメントを確認
4. **ネットワークエラー**: サブネットとルートテーブルを確認



