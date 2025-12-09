#!/usr/bin/env node
/**
 * ============================================
 * CDKアプリケーションのエントリーポイント
 * ============================================
 * 
 * 【構造】
 * - CDKアプリケーション（App）のインスタンスを作成
 * - スタック（CdkDockerSaaStack）をアプリに追加
 * 
 * 【用途】
 * - CDKデプロイ時の実行エントリーポイント
 * - `npx cdk deploy` 実行時にこのファイルが実行される
 * - AWSアカウントとリージョンの設定を環境変数から取得
 * 
 * 【実行方法】
 * - `npx cdk deploy` でデプロイ
 * - `npx cdk synth` でCloudFormationテンプレートを生成
 */
import * as cdk from 'aws-cdk-lib';
import { CdkDockerSaaStack } from '../lib/cdk-docker-saa-stack';

const app = new cdk.App();
new CdkDockerSaaStack(app, 'CdkDockerSaaStack', {
  /* AWS Account and Region are automatically resolved from AWS CLI configuration */
  env: { 
    account: process.env.CDK_DEFAULT_ACCOUNT || process.env.AWS_ACCOUNT_ID,
    region: process.env.CDK_DEFAULT_REGION || process.env.AWS_DEFAULT_REGION || 'ap-northeast-1'
  },
});
