# 作業

## 1. 変更前の構成 (REQ-019-S01、NREQ-002-S02、NREQ-002-S03)

- [x] 1.1 復元の回帰テストを作り、最小表示に対して失敗することを確認する。
- [x] 1.2 対象のUIと既存テストを基準へ戻し、同じ検査の成功とUI3ファイルの一致を確認する。
- [x] 1.3 廃止した3シナリオの専用テストを過去の記録へ移し、manual-checks.mdの参照を削除する。

## 2. 仕様と表示文書 (REQ-018-S01、REQ-020-S01、NREQ-001-S01、NREQ-001-S02、NREQ-001-S03、NREQ-002-S01)

- [x] 2.1 README.md、openspec/tech.md、openspec/structure.mdを基準へ戻し、差分を確認する。
- [x] 2.2 manual-checks.mdの変更対象を未確認へ戻し、今回の観測範囲を記載して台帳を検証する。
- [x] 2.3 正式仕様の5要件を差分仕様と同じ内容へ更新し、npx --no-install openspec validate restore-complete-battle-interface --strictの成功を確認する。
- [x] 2.4 復元範囲、履歴とデータの保持、実画像の確認結果を記録する。

## 3. 全体検証

- [x] 3.1 npm run checkとstrict検証を成功させ、元のHELPとACTIONの検出力が維持されていることをレビューする。
