# 検証結果

対象はrefine-build-and-deploymentである。

| 観点 | 結果 |
| --- | --- |
| 完全性 | 6タスク完了、3要件と11シナリオを確認 |
| 正確性 | 3要件を実装とテストへ対応付け、11シナリオの検査に成功 |
| 一貫性 | D-01からD-03の設計、既存コンポーネントと技術上の判断基準に一致 |

## 要件と実装の対応

| 要件 | 実装 | 検査 |
| --- | --- | --- |
| REQ-014 | ui/main.gdの_buildと_focus_modal | tests/build_dialogs.gdの_slot_switch、tests/interface_hierarchy.gd、既存の構成検証 |
| REQ-042 | ui/build_dialog.gd、ui/assembly_dialog.gd、game/build_choices.gd | tests/build_dialogs.gdの_compact_contentと既存の候補、確定、取消、入力の検査 |
| REQ-060 | game/spawn_layout.gd、game/battle.gdのstart、OPERATIONの開始可能領域 | tests/three_unit_squads.gdの_deployment、tests/panel_generation.gdの接続検査 |

REQ-014-S01、REQ-042-S02とREQ-042-S05の変更しない境界は、既存のテストを維持して確認した。\
REQ-014-S02、REQ-042-S01、REQ-042-S03、REQ-042-S04とREQ-042-S06は、選択先の完全一致、指定文の不在、色順の配列と実リング呼出しの有無で検査した。\
REQ-060-S01からREQ-060-S03は4ステージ各64シードで確認した。\
異なるシードを同じ固定配置へ置き換える誤り、誤ったフォーカス、残った補助文やSKILLリングを実装前の失敗で捕捉した。\
新テストはBUILDで10失敗、配置で4失敗から成功へ変わった。

## 設計との一致

- D-01: 現在SLOTだけを初期フォーカスへ渡し、全画面のキーボード操作を無効にしていない。
- D-02: 選択種を限定して説明と比較リングを省き、候補の実CORE順と設定色を使う。ARMSとGEARのモーダル領域は旧版と画素が一致する。
- D-03: 開始時だけ独立した乱数を使い、実配置の後でパネルを生成し、目標上の守備役を維持する。

固定座標が前提の既存の作用テストは、明示的なfixtureへ接続して同じ期待値を維持した。\
バランスの固定期待値、新しい検査コマンド、保存形式の変更は追加していない。

## 実行した検査

npm run check、変更のstrict検証とstrictトレース検証、git diff --checkに成功した。\
実Godotの補助検証は日英、1920x1080と1152x648で48項目すべて成功し、独立したSAVEとLOAD、CLASSとSKILLの適用、取消、各画面の収まり、通常開始の変化と指定シードの再現を確認した。\
詳細はartifacts/refine-build-review.mdとartifacts/runtime/refine-buildのログに残した。

## 指摘と確認限界

CRITICAL、WARNINGとSUGGESTIONはなし。\
適用対象の完全性、要件実装、シナリオ、設計とコード構成の確認を省略していない。\
自然な一戦の完走、全シードの列挙、音声の聴感と既存の実機確認台帳30件は今回の完了条件ではなく、未確認のまま維持した。\
Libraryは正規ヘルパーがprepare_uploads利用不能で停止したため、ローカル画像のみ完成し、添付IDは未取得である。\
すべての検証に成功し、アーカイブ可能である。
