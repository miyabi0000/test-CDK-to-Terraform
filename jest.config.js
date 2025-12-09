/**
 * ============================================
 * Jestテスト設定ファイル
 * ============================================
 * 
 * 【構造】
 * - testEnvironment: テスト実行環境（node）
 * - roots: テストファイルの検索ルート（test/）
 * - testMatch: テストファイルのパターン（*.test.ts）
 * - transform: TypeScriptファイルの変換設定（ts-jest）
 * 
 * 【用途】
 * - Jestテストランナーの設定を定義
 * - `npm test` 実行時にこの設定が使用される
 * - TypeScriptファイルをテスト実行前にJavaScriptに変換
 * 
 * 【テスト実行方法】
 * - `npm test` でテストを実行
 * - test/ ディレクトリ内の *.test.ts ファイルが実行される
 * 
 * 【注意】
 * - 現在はテストファイルが空のため、実際のテストは未実装
 * - テストを追加する場合は test/ ディレクトリに *.test.ts ファイルを作成
 */

module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
