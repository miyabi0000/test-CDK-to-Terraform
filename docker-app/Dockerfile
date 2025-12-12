# Dockerイメージ定義ファイル
# AWS Fargateで実行するNode.jsアプリケーション用
# ビルド方法（Mac ARM64）: docker buildx build --platform linux/amd64 -t saa-learning-app:latest .

FROM node:18-alpine

WORKDIR /app

# 依存関係のインストール
COPY package*.json ./
RUN npm ci --only=production

# アプリケーションコードのコピー
COPY . .

# ポート3000でリッスン
EXPOSE 3000

# アプリケーション起動
CMD ["node", "server.js"]
