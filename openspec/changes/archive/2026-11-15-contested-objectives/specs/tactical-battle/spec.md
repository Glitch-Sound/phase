# 差分仕様

## ADDED Requirements

### Requirement: REQ-023 - 競合する目標

BREACHとANCHORは最大移動力を装備しても初回行動では勝利目標へ到達できず、守備ユニットと独立した敵側の敗北目標を持ち、敵の到達または占有でも結果になり、勝敗目標を画面で区別できなければならない(SHALL)。

#### Scenario: REQ-023-S01 - 初手報酬の防止

- **GIVEN** 初期構成と移動+1を持つ最速の構成による全ステージ
- **WHEN** 最初の行動で可能な移動とアクションを全探索する
- **THEN** いずれも勝利せず、RESULTに入らず、BREACHとANCHORの最短到達は敵に行動機会を与える

#### Scenario: REQ-023-S02 - 放置すると敗北する目標

- **GIVEN** BREACHとANCHORで敵の前進を妨げないPLAYER
- **WHEN** 敵が対抗目標へ合法経路で進む
- **THEN** BREACHは敵Bの移動確定で、ANCHORはENEMYの手番終了でDEFEATとなる

#### Scenario: REQ-023-S03 - 相互に行動する戦闘

- **GIVEN** 両陣営が移動と攻撃と負傷時の回復を選ぶ戦闘
- **WHEN** 再現可能な操作列を最後まで実行する
- **THEN** 両陣営の攻撃と回復を含んで勝敗まで完走し、同じ操作列で同じ結果となる
