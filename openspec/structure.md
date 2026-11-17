# 構成

## ディレクトリ構成

| パス | 責務 |
| --- | --- |
| project.godot、main.tscn | Godot起動点 |
| game/ | 位相計算、戦闘、収集、カタログ、調整値 |
| ui/ | 描画、画面、入力 |
| tests/ | モデルと保存の検証、プレイ再現 |
| scripts/ | プロダクト検査、トレース検査 |
| artifacts/ | 検証ログとレビュー |
| openspec/ | 仕様、設計、変更、実機確認 |
| .agents/skills/ | OpenSpec生成スキル |
| .tool-cache/ | 開発キャッシュと設定(管理対象外) |
| .template-source/ | 取得したテンプレート(管理対象外) |

## 配置原則

モデルから画面へ依存しない。
ビルドと収集の保存をgame/collection.gdに集約する。
リングと波形はui/visuals.gdで手続き的に描く。
配色と判読性はui/palette.gd、操作アイコンと権利表示はassets/lucide/に集約する。
CPUの判断はgame/cpu_policy.gd、段階と表示時間はui/cpu_turn.gdへ分離し、どちらも既存のbattleを操作する。

## 命名規則

GDScript標準のsnake_caseに従う。
固定の全体ユニット順と陣営内の表示識別子を区別する。
