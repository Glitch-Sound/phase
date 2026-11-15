# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-018 - 経路入力表示

画面は経路番号、ノード間の線、設定したアクセント色の終点、対象範囲、有効対象、選択、ホバーを表示し、HELPで最終セルのダブルクリックを知らせなければならない(SHALL)。

#### Scenario: REQ-018-S01 - 経路操作

- **GIVEN** 移動状態の戦闘画面
- **WHEN** 経路追加、取消、ダブルクリック、対象選択を操作する
- **THEN** 番号と終点が追随し、行動選択とBACKが動作する

## ADDED Requirements

### Requirement: REQ-029 - 中央マップ周辺の文字

WHILE 戦闘盤面が表示される間、画面は中央マップ周辺の操作説明、ステージ名、ゲームモード名、座標数字、勝利条件文を表示してはならない(SHALL NOT)。

#### Scenario: REQ-029-S01 - 状態とステージの切替

- **GIVEN** 戦闘盤面が表示されるゲーム
- **WHEN** 以下の表示へ切り替える
- **THEN** 中央マップ周辺に指定した5種の文字を表示しない

| ステージ | 表示状態 |
| --- | --- |
| INTERFERENCE | 移動 |
| SEVERANCE | 移動 |
| BREACH | 移動 |
| ANCHOR | 移動 |
| INTERFERENCE | 行動選択 |
| INTERFERENCE | 攻撃対象選択 |
| INTERFERENCE | 回復対象選択 |
| INTERFERENCE | 閉塞してWAIT可能 |
| INTERFERENCE | RESULTの背後 |
