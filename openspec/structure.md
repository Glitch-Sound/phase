# 構成

## ディレクトリ構成

| パス | 責務 |
| --- | --- |
| project.godot、main.tscn | Godot起動点 |
| DEVELOPMENT.md | OpenSpecを使う開発者向けの手順と道具の設定 |
| game/ | 位相計算、戦闘、収集、カタログ、調整値 |
| ui/ | 描画、画面、入力、説明言語 |
| assets/sfx/ | 本人提供の原音と出典の確認状況 |
| docs/assembly-v1.md | アセンブリの別図案、色キーと表示規約 |
| docs/identicon-v1.md | 端末間で共有する名前と紋章の固定規約 |
| tests/ | モデルと保存の検証、プレイ再現 |
| scripts/ | プロダクト検査、トレース検査 |
| artifacts/ | 検証ログとレビュー |
| openspec/ | 仕様、設計、変更、実機確認 |
| .agents/skills/ | OpenSpec生成スキル |
| .tool-cache/ | 開発キャッシュと設定(管理対象外) |
| .template-source/ | 取得したテンプレート(管理対象外) |

## 配置原則

モデルから画面へ依存しない。
game/spawn_layout.gdが開始位置と可能な範囲を生成し、battleが実位置を確定してからgame/panel_layout.gdで開始セルを除外する。\
OPERATIONの概要図は固定位置の代わりに同じ開始可能領域を使う。
ビルドと収集の保存をgame/collection.gdに集約する。\
構成候補と可否、原本から独立したプレビューはgame/build_choices.gd、共通の選択画面はui/build_dialog.gdへ置く。
game/unit_identity.gdが表示名の規約と固定の幾何を生成し、戦闘の不変IDと構成には名前を混ぜない。\
game/assembly_identity.gdが独立した所属紋章と安定色キーと共通RGB、視点の所有規則を持ち、ui/assembly_dialog.gdが候補だけを編集する。\
リングと波形、両方の紋章はui/visuals.gdで手続き的に描く。\
目標文の固定参照はui/unit_reference_text.gdで紋章へ置換し、名前を非表示のアクセシビリティ用名称に保持する。
配色と判読性はui/palette.gd、操作アイコンと権利表示はassets/lucide/に集約する。\
表示モードの保存と安定確認はui/display_settings.gd、説明言語の解決と独立設定はui/language.gd、説明の日本語対訳はui/japanese.gdへ置き、モデルの名称と説明の原文を変更しない。\
表示は説明の原文を保持して更新し、ui/unit_reference_text.gdの段落組版は固定参照を紋章で描く。
CPUの判断はgame/cpu_policy.gd、段階と表示時間はui/cpu_turn.gdへ分離し、どちらも既存のbattleを操作する。
経路と行動の予定はui/turn_plan.gd、各歩の描画補間はui/movement.gdへ分離する。\
予定は原本を変更せず、描画はモデルへ書き戻さずに画面とCPUの連続実行を同期する。
ui/sfx.gdは回転と実HP変化の発音条件と音声レーンを所有し、画面からだけ呼び出す。\
原音はassets/sfxに保持し、権利の確認状況は同じ場所のNOTICE.mdへ記録する。

## 命名規則

GDScript標準のsnake_caseに従う。
固定の全体ユニット順と陣営内の表示識別子を区別する。
