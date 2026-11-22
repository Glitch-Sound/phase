# 検証

## 判定

| 観点 | 結果 |
| --- | --- |
| 完全性 | 4タスク、1要件、4シナリオを確認した |
| 正確性 | モデルと予定、UIとCPUの接続を確認した |
| 一貫性 | D-01、D-02と既存の計算と表示の分離に一致する |

## 対応

| シナリオ | 実装 | 証拠 |
| --- | --- | --- |
| REQ-012-S01 | battle.wait_turn | tests/run.gdの空き隣接と閉塞の状態全体の比較 |
| REQ-012-S02 | 既存のenter_cell、preview、reselect_path | 変更していないtests/core_panels.gdの受動、予測と確定、取消 |
| REQ-012-S03 | battleの選択、作用予測と実行、turn_planの空経路拒否 | tests/run.gdの5系統の拒否、tests/turn_plan.gdの偽造予定とtests/cpu_turn.gdの接続 |
| REQ-012-S04 | mainの常設WAIT、turn_planの空経路、確認と取消 | tests/decision_interface.gdの実画面部品、BACKとEsc、再確認拒否と移動音なし |

実装前の失敗と、古い経路を描く誤実装の失敗を確認した。\
文字列の部分一致ではなく、WAITの確認名、実行コマンド、状態の全体、履歴と手番の回数を比較する。\
CPUの空経路の処理は既存実装でも成立するため、その接続確認は最初から成功する。\
既存の作用を検証する移動後のテストは移動数を明示し、期待する作用を弱めていない。

npm run check、差分、差分仕様の厳密検証とトレースが成功した。\
Godotの補助確認18件は成功し、隔離した最小と標準のGUIでWAIT、取消とCPUの閉塞を確認した。\
詳細と限界はartifacts/stationary-wait-review.mdへ記録した。\
既存の利用者による実機確認の未確認行は、今回の自動検証とは区別して維持した。

CRITICAL、WARNING、SUGGESTIONの指摘と未検証の仕様項目はない。\
仕様、実装と自動テストの同期が可能な状態である。
