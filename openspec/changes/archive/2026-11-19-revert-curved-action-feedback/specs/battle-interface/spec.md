# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-021 - 効果フィードバック

WHEN 効果が実行されるとき、画面はダメージをINF色の負数、回復をRES色の正数(既定は赤と緑)、撃破をDEFEATEDとして対象付近から上昇しフェードする表示にしなければならない(SHALL)。

#### Scenario: REQ-021-S01 - 効果表示

- **GIVEN** 負傷と撃破と回復が起こる戦闘
- **WHEN** それぞれのスキルを使用する
- **THEN** HP変化と対応する符号、色、DEFEATEDを表示する
