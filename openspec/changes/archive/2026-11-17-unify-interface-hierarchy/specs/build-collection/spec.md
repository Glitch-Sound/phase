# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-014 - 共有ビルド

WHEN 戦闘外で編集するとき、各PLAYERはCLASS、合計100のCORE、開放済み装備と変異、重複しない最大3スキルを共有一覧から設定できなければならない(SHALL)。

#### Scenario: REQ-014-S01 - 構成検証

- **GIVEN** 共有装備とNORMAL、REVERSE、未設定スキル
- **WHEN** ビルドを検証する
- **THEN** 空スキルと同一装備の複数人利用を許可し、未開放装備、重複スキル、不正変異は拒否する

#### Scenario: REQ-014-S02 - BUILDの情報階層

- **GIVEN** 両ユニットと開放済み装備、変異、スキル、4ステージ
- **WHEN** BUILDで構成を編集して出撃条件を選ぶ
- **THEN** ユニット切替、CLASS、COREの5値と総量と再配分規則、ARMSとGEARの型番と5値と差分、変異、3スキル枠、HPと移動と待ち量とINF補正、ステージと勝利条件と案内、共有一覧の数量を確認できる
- **AND** 主要な編集、構成の結果、装備の比較と出撃を余白と強弱で区別し、SAVE、LOAD、HELP、SETTINGS、QUIT、STARTの操作を維持し、情報を恒久的に隠したり削除したりしない

