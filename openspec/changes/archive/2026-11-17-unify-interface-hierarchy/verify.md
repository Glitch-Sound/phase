# 検証記録

## 判定

| 観点 | 結果 |
| --- | --- |
| 完全性 | 5/5タスク、3/3要件に実装と検査の対応がある |
| 正確性 | 17/17シナリオを対応付けた。実表示の最終評価は既存の実機未確認として維持 |
| 一貫性 | D-01、D-02、D-03と既存のUI、検査構成に整合する |

CRITICAL、WARNING、SUGGESTIONの指摘はない。
必要な情報を削除する変更、戦闘モデルと保存形式の変更はない。
ただしREQ-019-S01とNREQ-002-S01の全状態と任意の配色での実表示の最終評価は未確認である。
実機の確認範囲と限界はartifacts/interface-hierarchy-review.mdに記録した。
この記録は全画面の最終承認を意味しない。
LibraryのID取得は保存機能の利用不可により未完了であり、ローカル画像を納品する。

## 対応

| シナリオ | 実装 | 検査と証拠 |
| --- | --- | --- |
| REQ-014-S01 | game/collection.gd、ui/main.gdの編集接続 | tests/run.gd、interface_hierarchy.gdの検証専用保存と編集 |
| REQ-014-S02 | ui/main.gdの_build、_equipment_values、_refresh_build | interface_hierarchy.gdの正確な操作集合と全情報、全ステージ、配分と差分、GPUの4サイズ |
| REQ-019-S01 | _cell_input、_draw_left、_draw_right、円形予測 | phase_preview.gdとrestored_interface.gd、通常Godotの観測。最終目視は未確認を維持 |
| REQ-019-S03 | battle_labelsとside_informationの非表示方針 | battle_labels.gd、side_information.gdの厳密な非表示検査 |
| REQ-019-S04 | _draw_left、_draw_right、_hud | side_information.gdとtime_axis.gd、GPUの戦闘画像 |
| REQ-019-S05 | _draw_left | phase_preview.gdの空値と最大値と横の段 |
| REQ-019-S06 | _timeline_viewと時間軸の描画 | time_axis.gdの同値、待ち0と最大待ち、等間隔 |
| REQ-019-S07 | 時間軸の選択と_hover、_cell_input | time_axis.gdの独立した選択と経路、実入力のTURN18 |
| REQ-019-S08 | _timeline_view | time_axis.gdの撃破と終了、手番更新 |
| REQ-019-S09 | _draw_right | side_information.gdの識別名、全スキルと装備アイコン、回帰と戦闘画像 |
| REQ-019-S10 | _draw_timeline | time_axis.gdのTURNの桁と更新、戦闘画像 |
| REQ-019-S11 | ui/visuals.gdの補正率 | time_axis.gdの固定幅、境界と無効値 |
| REQ-019-S12 | _draw_left、game/tuning.gd | phase_preview.gdの実描画記録の順序と最大HP、空HP。旧順への変異は4件失敗 |
| NREQ-002-S01 | _set_theme、_modal、_build | design_flow.gd、interface_hierarchy.gd、既定色とAMBERのGPU、通常Godotの代表観測。最終目視は未確認を維持 |
| NREQ-002-S02 | 既存の同梱Lucideとラベル | design_flow.gd。新たな素材と依存の追加なし |
| NREQ-002-S03 | 既存のモーダルフォーカスと共通テーマ | design_flow.gd、interface_hierarchy.gd、各サイズのGPUと通常GodotのTabとBACK |
| NREQ-002-S06 | _set_theme、_modal、_button | interface_hierarchy.gdの面、全辺、下線、ホバー、選択と不透明なリスト。枠、緑のフォーカス、透明リストへの変異を検出 |

## 検査の品質

操作の個数だけでなく全ラベル集合を完全一致で検査した。
装備の5値と符号付き差分は対象関数から期待値を作らず、独立した完全一致で検査した。
保存から読み込まれた整数相当の浮動小数点値も同じ表示へ正規化されることを完全一致で検査し、修正前の1件の失敗と修正後の成功を確認した。
HPは同じ段だけでなく、陣営名の右端、バーの両端、数値の両端と盤面の左端の順序を比較した。
各枠の全4辺を確認し、フォーカスは白い下線以外の辺がないことを確認した。
単なる部分文字列の一致だけで誤実装が通らないことを6種の変異で確認した。
詳細なREDとGREENと変異結果はレビュー記録とartifacts/runtimeにある。

## 設計との一致

D-01は調整定数と同じ段のHP順に反映した。
D-02は共通の面と操作状態へ反映し、戦闘システムメニューの既存表現を個別のスタイルで保った。
D-03は3列と装備5列の比較へ反映し、右の説明は全文を折り返して維持した。
保存先の注入はUI接続の検査専用で、既定の保存先と通常の保存動作は変えていない。
既存のGDScriptとSceneTreeによる検査の形に従い、関係のないリファクタリングを混ぜていない。
