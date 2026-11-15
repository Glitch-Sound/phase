# 実装整合性の検証

## 概要

| 観点 | 結果 |
| --- | --- |
| 完全性 | 9/9タスク、23/23要件の実装箇所を確認した |
| 正しさ | 24の自動シナリオが成功した。実機6項目中2項目は確認済み、4項目は部分観測でありNot verifiedとする |
| 一貫性 | D-01からD-04の配置、責務、保存、描画の方針と一致する |

## 要件と実装

| 要件 | 実装箇所 |
| --- | --- |
| REQ-001 | phase_math.gdのvalid_stats、catalog.gdのserial |
| REQ-002 | phase_math.gdのmax_hp |
| REQ-003 | phase_math.gdのenter_panel |
| REQ-004 | phase_math.gdのoverlapとsector |
| REQ-005 | phase_math.gdのsyncとtolerance |
| REQ-006 | phase_math.gdのsingularity |
| REQ-007 | phase_math.gdのeffect、battle.gdのact |
| REQ-008 | phase_math.gdのdelay、battle.gdのnext_actor、timeline、_end_turn |
| REQ-009 | battle.gdのpath_click |
| REQ-010 | battle.gdのpreviewとcommit_path、main.gdの_cell_input |
| REQ-011 | battle.gdのchoose_skill、valid_target、act、back |
| REQ-012 | battle.gdのmovement、trapped、wait_turn |
| REQ-013 | battle.gdのcheck_resultと条件判定、catalog.gdのstages |
| REQ-014 | collection.gdのvalid_build、main.gdの_build |
| REQ-015 | collection.gdのroll_lootとaccept_drop |
| REQ-016 | collection.gdのsave_to、load_from、_validate_snapshot |
| REQ-017 | main.gdの_build、_start_battle、_result |
| REQ-018 | main.gdの_cell_input、_draw_board、_action_dialog |
| REQ-019 | main.gdの_draw_left、_draw_info、_draw_preview、visuals.gd |
| REQ-020 | main.gdの_help、_settings、_restart、_quit |
| REQ-021 | main.gdの_feedback、_process、_draw |
| REQ-022 | battle.gd全体の非乱数進行、playthrough.gdの操作列再現 |
| NREQ-001 | project.godotの基準寸法、main.gdの中央配置と70セル |

## 正しさの確認

539件のモデルチェック、12件の画面接続チェック、PLAYER勝利20手番とENEMY勝利18手番の完走を確認した。
手計算に基づく部分同期の期待値と、故意の誤実装4件の検出を確認した。
全体検証とchangeのstrict validate、strict traceが成功した。
検査スクリプトを弱めたり無効にしたりしていない。

## 未確認の範囲

以下は機能の欠落ではなく、画面と実機条件の確認範囲の限界である。
自動検査の成功をもって実画面の確認済みとはしていない。

- REQ-019-S01: 別ユニット選択の接続は検査済みだが、選択時の読みやすさは実機で最終確認する。
- REQ-020-S01: Godotの埋め込み実行では、独立ウィンドウのフルスクリーンの実効を確認できなかった。
- REQ-021-S01: 回復の実量表示とDEFEATEDの接続は検査済みだが、修正後の全演出の実画面確認は残る。
- NREQ-001-S01: 1440相当表示は観測したが、1920の独立実行は残る。

## 指摘

実施したコード、仕様、テストの整合検査にCRITICALとWARNINGの指摘はない。
未確認の4項目はmanual-checks.mdで管理する。
面白さと長期戦の調整はartifacts/verification.mdに記録した。
ユーザーの最終確認は未実施であり、全実機条件を検証済みとはしない。
アーカイブは内部の仕様一致の記録とし、運用開始や公開の承認を意味しない。
