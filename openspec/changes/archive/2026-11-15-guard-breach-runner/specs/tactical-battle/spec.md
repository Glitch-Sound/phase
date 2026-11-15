# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-013 - 勝敗条件

各ステージは勝利と敗北のそれぞれへELIMINATE、TARGET、REACH、OCCUPYを設定可能とし、戦闘不能、移動確定、手番終了の対応する時機に判定して成立直後に終了し、同時成立時は敗北を優先しなければならない(SHALL)。

#### Scenario: REQ-013-S01 - 目標の時機

- **GIVEN** 4種の目標を設定した戦闘
- **WHEN** 対応する契機を発生させる
- **THEN** ELIMINATEとTARGETは撃破時、REACHは確定時、OCCUPYは終了時にだけ結果となる

#### Scenario: REQ-013-S02 - 敗北と除外

- **GIVEN** 最後のPLAYERが戦闘不能になる戦闘
- **WHEN** ダメージを適用する
- **THEN** DEFEATとなり、死亡ユニットのセルは通行可能となる

#### Scenario: REQ-013-S03 - ステージ固有の敗北

- **GIVEN** 敵AのREACHを敗北条件とし、味方02のOCCUPYを勝利条件とした戦闘
- **WHEN** 該当するユニットが条件を満たす
- **THEN** 敵Aの移動確定でDEFEATとなり、味方01の占有では勝利せず、味方02の手番終了でだけVICTORYとなる

#### Scenario: REQ-013-S04 - 同時成立の優先

- **GIVEN** 勝利と敗北の両条件が同じ判定時機に成立する戦闘
- **WHEN** 撃破、移動確定、手番終了それぞれの判定を行う
- **THEN** いずれもDEFEATとなり、後の判定で結果は変わらない

### Requirement: REQ-023 - 競合する目標

BREACHとANCHORは最大移動力を装備しても初回行動では勝利目標へ到達できず、守備ユニットと独立した敵側の敗北目標を持ち、敵の到達または占有でも結果になり、勝敗目標を画面で区別でき、BREACHでは到達役01の戦闘不能で直ちに敗北しなければならない(SHALL)。

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

#### Scenario: REQ-023-S04 - 到達役を失った戦闘

- **GIVEN** BREACHで02が生存し、敵が生存する場合と敵全滅の場合
- **WHEN** 01の戦闘不能を判定する
- **THEN** 敵の残存にかかわらず直ちにDEFEATとなる

#### Scenario: REQ-023-S05 - 敵全滅後の到達

- **GIVEN** BREACHで01が生存し、02と敵全員が戦闘不能でも到達未達成で継続している戦闘
- **WHEN** 01が指定目標への移動を確定する
- **THEN** VICTORYとなる
