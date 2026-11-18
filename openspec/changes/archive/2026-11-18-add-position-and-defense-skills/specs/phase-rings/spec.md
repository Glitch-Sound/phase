# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-003 - 進入時回転

WHEN 通常移動、SWAPまたはPUSHでパネルへ進入するとき、ゲームは全ユニットのGEARをそのSPDの1.5倍だけ反時計回り、ARMSをそのSPDの1.5倍だけ時計回りへ回転し、NORMALではCOREを保持し、RESETではCOREを戦闘開始角へ戻し、CLOCKWISEとCOUNTERCLOCKWISEではCOREのSPDの1.5倍だけ指定方向へ回転し、パネル無視を装備した本人は特殊パネルのCORE効果だけを無視し、経路順に適用して角度を次手番へ保持し、再戦では開始基準を新しく設定しなければならない(SHALL)。

#### Scenario: REQ-003-S01 - パネル効果

- **GIVEN** CORE、GEAR、ARMSのSPDが20、現在のCORE角90度、戦闘開始CORE角15度、両装備角0度
- **WHEN** 次のパネルへ1回進入する
- **THEN** GEARは330度、ARMSは30度となり、COREは次の角度となり、能力値や開始基準は変わらない

| パネル | CORE角度 |
| --- | --- |
| NORMAL | 90度 |
| RESET | 15度 |
| CLOCKWISE | 120度 |
| COUNTERCLOCKWISE | 60度 |

#### Scenario: REQ-003-S02 - リセットと経路順

- **GIVEN** CORE角40度、戦闘開始角10度、COREのSPD20
- **WHEN** 特殊パネルを連続して踏む
- **THEN** CLOCKWISEの後にRESETなら10度、RESETの後にCLOCKWISEなら40度となり、連続する回転は累積し、0度と360度の境界で循環する

#### Scenario: REQ-003-S03 - 陣営と持続と再戦

- **GIVEN** 味方と敵が特殊パネルを踏んだ戦闘
- **WHEN** 手番が交代し、その後に同じビルドで新しい戦闘を開始する
- **THEN** 交代中は変更後の角度を保持し、同じ規則が敵にも適用され、新しい戦闘では全員のCORE現在角とリセット基準が開始角0度へ戻り、前戦の角度を引き継がない

#### Scenario: REQ-003-S04 - パネル無視と通常回転

- **GIVEN** CORE角90度、開始角15度、各SPD20と装備角0度でパネル無視を装備したユニット
- **WHEN** NORMAL、RESET、CLOCKWISE、COUNTERCLOCKWISEのいずれかへ1回進入する
- **THEN** 全種類でCOREは90度、GEARは330度、ARMSは30度となり、能力値と開始角は変わらず、通常移動と強制移動で同じ規則を使う

### Requirement: REQ-007 - ダメージと回復

アクションは指定INF係数と同期補正から効果量を求め、ダメージを1+RES係数と同期の積で除し、特異点倍率の後に切り捨て、防御状態の対象へのDAMAGEだけは切捨て後の値へ設定した軽減率を適用して再度切り捨て、回復はRESを使わず最大HP以下にしなければならない(SHALL)。

#### Scenario: REQ-007-S01 - 効果量

- **GIVEN** 全ステータス20、完全同期の攻守
- **WHEN** ダメージと回復を計算する
- **THEN** ダメージはfloor(BASE_DAMAGE*2/3)、回復はfloor(BASE_HEAL*2)となる

#### Scenario: REQ-007-S02 - 回復上限

- **GIVEN** 最大100、現在95の隣接味方
- **WHEN** 回復を実行する
- **THEN** 現在HPは100となり戦闘不能には回復できない

#### Scenario: REQ-007-S03 - 防御の予測と整数化

- **GIVEN** 同じ攻守の防御ありとなし、回復対象
- **WHEN** 作用を予測する
- **THEN** 防御時のDAMAGEは通常式の非負整数へ設定した軽減率を適用した切捨て値となり、HEALと防御なしの値は変わらず、予測だけでは防御を消費しない
