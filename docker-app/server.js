/**
 * ============================================
 * Node.jsアプリケーション（Express + PostgreSQL）
 * ============================================
 * 
 * 【構造】
 * - Express: Webサーバーフレームワーク
 * - PostgreSQL: データベース接続（pgライブラリ）
 * - 3つのエンドポイント:
 *   1. GET / - メインエンドポイント（アプリ情報）
 *   2. GET /health - ヘルスチェック（DB接続確認）
 *   3. GET /db-info - データベース情報取得
 * 
 * 【用途】
 * - ECS Fargateで実行されるアプリケーション
 * - ALBからリクエストを受けて処理
 * - RDS PostgreSQLに接続してデータを取得
 * 
 * 【環境変数】
 * - PORT: サーバーのポート（デフォルト: 3000）
 * - DATABASE_HOST: RDSのエンドポイント
 * - DATABASE_PORT: RDSのポート（デフォルト: 5432）
 * - DATABASE_NAME: データベース名
 * - DATABASE_USERNAME: データベースユーザー（Secrets Managerから取得）
 * - DATABASE_PASSWORD: データベースパスワード（Secrets Managerから取得）
 * 
 * 【実行方法】
 * - Dockerコンテナ内で `node server.js` で起動
 * - ポート3000でリッスン
 * - 0.0.0.0でバインド（コンテナ外からアクセス可能）
 */

const express = require('express');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3000;

// データベース接続設定
const pool = new Pool({
  host: process.env.DATABASE_HOST,
  port: process.env.DATABASE_PORT || 5432,
  database: process.env.DATABASE_NAME,
  user: process.env.DATABASE_USERNAME,
  password: process.env.DATABASE_PASSWORD,
  ssl: {
    rejectUnauthorized: false
  }
});

// ヘルスチェックエンドポイント
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'healthy', database: 'connected' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected', error: error.message });
  }
});

// メインエンドポイント
app.get('/', (req, res) => {
  res.json({
    message: 'SAA学習用アプリケーション',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

// データベース情報取得エンドポイント
app.get('/db-info', async (req, res) => {
  try {
    const result = await pool.query('SELECT version()');
    res.json({
      database: 'PostgreSQL',
      version: result.rows[0].version,
      connected: true
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});



