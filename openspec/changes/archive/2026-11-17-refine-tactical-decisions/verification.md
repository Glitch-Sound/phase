# 検証報告

## 結果

| 観点 | 結果 |
| --- | --- |
| 完全性 | ears-bddの全4成果物と6/6タスクを確認、MODIFIEDの3要件を実装した |
| 正確性 | 3/3要件と11/11シナリオの実装と検証経路を確認した |
| 一貫性 | D-01、D-02、D-03とtech.md、既存の決定的なモデルと描画パターンに一致した |

ADDED、REMOVED、RENAMEDの要件はない。
実装にCRITICAL、WARNING、SUGGESTIONはない。
適用可能な検証を省略していない。
利用者自身の最終判定は、このコード検証とは別にmanual-checks.mdへ未確認で残す。

## シナリオの対応

| 対象 | 実装と証拠 |
| --- | --- |
| REQ-005-S01 | phase_math.gdの許容角、入力上限と補正、tests/run.gd、decision_model.gdでLUKと完全同期を確認した |
| REQ-005-S02 | sigmaへtuning.gdの0.90を適用、decision_model.gdの独立した低中高の計算と攻防回復、CPU12戦比較と実対戦で確認した |
| REQ-010-S01 | battle.previewとcommit_path、既存core_panels.gdとdecision_model.gdで経路順の予測と確定を比較した |
| REQ-010-S02 | battle.path_clickとMOVEのEsc、既存core_panels.gdとrestored_interface.gdで短縮と取消を確認した |
| REQ-010-S03 | battle.reselect_pathで辞書と履歴を復元、モデル3回の再確定と別経路、UIのBACKとEsc、GPU4サイズと通常操作で確認した |
| REQ-010-S04 | _end_turn、next_actorと終局で復元情報を破棄、UIのCPU保護、モデルのWAIT、攻撃、到達、再戦とCPUの回帰検査で確認した |
| REQ-018-S01 | ACTIONへBACK、Escへ同じ入口を接続、通常画面で経路確定から2通りで戻り再攻撃した |
| REQ-018-S02 | _route_segmentsを維持、既存route_clearance.gdとdecision_interface.gdで起点と上下左右の経路を確認した |
| REQ-018-S03 | 既存のcore_panel_ui.gd、panel_play.gdとHELPの実画面で3アイコンとCOREだけへの効果説明を維持した |
| REQ-018-S04 | セル枠の既存描画を維持、decision_interface.gdの幾何とGPU4サイズ、盤面端の実ピクセルを確認した |
| REQ-018-S05 | main._acting_markerと白い三角、全4ユニット、選択とホバー、端、AMBER、終局を自動検査と実描画、通常CPU戦で確認した |

各シナリオのテストIDと期待値を確認し、戻した全辞書と全履歴、正確なACTION操作集合と同じ実プレイ履歴を比較した。
復元辞書、履歴切詰め、sigma、選択と行動者の取り違え、Esc接続の5誤実装はそれぞれ7、3、9、5、1件の失敗で検出した。
すべての変更を復元してから最終コードを検査した。

## 検査

- npm run checkは成功した。
- npx --no-install openspec validate refine-tactical-decisions --strictは成功した。
- node scripts/openspec-trace.mjs check --change refine-tactical-decisions --strictは成功した。
- decision_model.gdは44件、decision_interface.gdは59件で失敗0だった。
- decision_capture.gdの本番モデルによるGPU検査は158件で失敗0だった。
- 実画面の27手番の勝利と16手の人の操作を再生し、各段階の履歴と最終HPを完全一致で確認した。
- 低中高の数式と実効量、12モデル戦、残り1体の限定例はdecision_analysis.gdとcpu_play.gdで比較した。

## 設計と限界

復元は1つのモデル入口へ集約し、角度の逆算と保存形式の変更はない。
補正は上限を増やさず幅だけを縮小し、救済案とCPU方針は変更していない。
三角は既存のtuningと手続き描画に従い、周辺の配置と配色は維持した。
実戦の面白さは主観と観測を分けてartifacts/tactical-decisions-review.mdに記録した。
全ビルドの一撃や全局面の停止不在、全ステージの人対CPU完走は主張しない。
利用者の最終確認12件は未確認のままで、今回のREQ-018-S01、REQ-018-S03、REQ-018-S05を含む。
通常画面のHELPを開き、白い三角と2種類のBACKの説明を読めることを確認し、EscでBUILDへ戻して画面操作を終了した。

実装と仕様の整合の検証は成功し、アーカイブ可能である。
