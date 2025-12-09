/**
 * ============================================
 * Dockerイメージ定義ファイル
 * ============================================
 * 
 * 【構造】
 * - FROM: ベースイメージ（node:18-alpine）
 * - WORKDIR: 作業ディレクトリの設定
 * - COPY: ファイルのコピー（package.json → アプリコード）
 * - RUN: コマンドの実行（npm ci）
 * - EXPOSE: 公開ポート（8080）
 * - CMD: コンテナ起動時のコマンド
 * 
 * 【用途】
 * - Dockerイメージのビルド定義
 * - ECS Fargateで実行するコンテナイメージを作成
 * - `docker build` でこのファイルからイメージをビルド
 * 
 * 【ビルド方法】
 * - Mac（ARM64）の場合: `docker buildx build --platform linux/amd64 -t saa-learning-app:latest .`
 * - Linuxの場合: `docker build -t saa-learning-app:latest .`
 * 
 * 【注意】
 * - AWS Fargateはx86_64（amd64）アーキテクチャを使用
 * - Macで開発する場合は必ず `--platform linux/amd64` を指定
 * - package-lock.jsonが必要（npm ciを使用）
 */

FROM node:18-alpine

WORKDIR /app

# 依存関係のインストール
COPY package*.json ./
RUN npm ci --only=production

# アプリケーションコードのコピー
COPY . .

# ポート8080でリッスン
EXPOSE 8080

# アプリケーション起動
CMD ["node", "server.js"]



