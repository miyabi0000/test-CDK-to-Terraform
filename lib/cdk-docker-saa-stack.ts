import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns';
import * as ecr from 'aws-cdk-lib/aws-ecr';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as logs from 'aws-cdk-lib/aws-logs';

export class CdkDockerSaaStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ============================================
    // 1. VPC の作成 (SAA学習: ネットワーク設計)
    // ============================================
    const vpc = new ec2.Vpc(this, 'SaaLearningVpc', {
      maxAzs: 2, // 高可用性のため2つのAZを使用
      natGateways: 1, // コスト削減のため1つのNAT Gateway
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

    // ============================================
    // 2. ECR リポジトリの作成 (Dockerイメージ保存)
    // ============================================
    const ecrRepository = new ecr.Repository(this, 'DockerAppRepository', {
      repositoryName: 'saa-learning-app',
      imageScanOnPush: true, // セキュリティ: イメージスキャン有効化
      lifecycleRules: [
        {
          maxImageCount: 10, // 古いイメージを自動削除
        },
      ],
    });

    // ============================================
    // 3. RDS データベースの作成 (SAA学習: データベース設計)
    // ============================================
    const dbSubnetGroup = new rds.SubnetGroup(this, 'DatabaseSubnetGroup', {
      vpc,
      description: 'Subnet group for RDS database',
      vpcSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
      },
    });

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
      subnetGroup: dbSubnetGroup,
      databaseName: 'saalearningdb',
      credentials: rds.Credentials.fromGeneratedSecret('dbadmin'),
      multiAz: false, // コスト削減のため単一AZ（本番環境ではtrue推奨）
      deletionProtection: false, // 学習用のため削除保護無効
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // セキュリティグループ: データベースへのアクセス許可
    database.connections.allowFrom(
      ec2.Peer.ipv4(vpc.vpcCidrBlock),
      ec2.Port.tcp(5432),
      'Allow database access from VPC'
    );

    // ============================================
    // 4. ECS クラスターの作成
    // ============================================
    const cluster = new ecs.Cluster(this, 'SaaLearningCluster', {
      vpc,
      clusterName: 'saa-learning-cluster',
      containerInsights: true, // CloudWatch Container Insights有効化
    });

    // ============================================
    // 5. ECS Fargate サービスの作成 (Dockerコンテナ実行)
    // ============================================
    const fargateService = new ecsPatterns.ApplicationLoadBalancedFargateService(
      this,
      'DockerFargateService',
      {
        cluster,
        serviceName: 'saa-learning-service',
        taskImageOptions: {
          image: ecs.ContainerImage.fromEcrRepository(ecrRepository, 'latest'),
          containerPort: 8080,
          logDriver: ecs.LogDrivers.awsLogs({
            streamPrefix: 'saa-learning',
            logGroup: new logs.LogGroup(this, 'AppLogGroup', {
              logGroupName: '/ecs/saa-learning',
              retention: logs.RetentionDays.ONE_WEEK,
              removalPolicy: cdk.RemovalPolicy.DESTROY,
            }),
          }),
          environment: {
            NODE_ENV: 'production',
            DATABASE_HOST: database.instanceEndpoint.hostname,
            DATABASE_PORT: '5432',
            DATABASE_NAME: 'saalearningdb',
          },
          secrets: {
            DATABASE_PASSWORD: ecs.Secret.fromSecretsManager(
              database.secret!,
              'password'
            ),
            DATABASE_USER: ecs.Secret.fromSecretsManager(
              database.secret!,
              'username'
            ),
          },
        },
        desiredCount: 2, // 高可用性のため2つのタスク
        publicLoadBalancer: true, // パブリックALB
        listenerPort: 80,
        healthCheckGracePeriod: cdk.Duration.seconds(60),
      }
    );

    // データベースへのアクセス許可
    database.connections.allowFrom(
      fargateService.service,
      ec2.Port.tcp(5432),
      'Allow ECS tasks to access database'
    );

    // ============================================
    // 6. タスク実行ロールへの権限付与
    // ============================================
    fargateService.taskDefinition.executionRole?.addToPrincipalPolicy(
      new iam.PolicyStatement({
        effect: iam.Effect.ALLOW,
        actions: [
          'secretsmanager:GetSecretValue',
          'secretsmanager:DescribeSecret',
        ],
        resources: [database.secret!.secretArn],
      })
    );

    // ============================================
    // 7. 出力値の設定
    // ============================================
    new cdk.CfnOutput(this, 'LoadBalancerDNS', {
      value: fargateService.loadBalancer.loadBalancerDnsName,
      description: 'DNS name of the load balancer',
      exportName: 'LoadBalancerDNS',
    });

    new cdk.CfnOutput(this, 'ECRRepositoryURI', {
      value: ecrRepository.repositoryUri,
      description: 'ECR Repository URI for Docker images',
      exportName: 'ECRRepositoryURI',
    });

    new cdk.CfnOutput(this, 'DatabaseEndpoint', {
      value: database.instanceEndpoint.hostname,
      description: 'RDS Database endpoint',
      exportName: 'DatabaseEndpoint',
    });

    new cdk.CfnOutput(this, 'DatabaseSecretArn', {
      value: database.secret!.secretArn,
      description: 'ARN of the database secret',
      exportName: 'DatabaseSecretArn',
    });
  }
}
