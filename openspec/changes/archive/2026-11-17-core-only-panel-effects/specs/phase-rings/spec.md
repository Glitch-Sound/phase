# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-003 - 進入時回転

WHEN パネルへ進入するとき、ゲームは全ユニットのGEARをそのSPDの1.5倍だけ反時計回り、ARMSをそのSPDの1.5倍だけ時計回りへ回転し、NORMALではCOREを保持し、RESETではCOREを戦闘開始角へ戻し、CLOCKWISEとCOUNTERCLOCKWISEではCOREのSPDの1.5倍だけ指定方向へ回転し、経路順に適用して角度を次手番へ保持し、再戦では開始基準を新しく設定しなければならない(SHALL)。

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
