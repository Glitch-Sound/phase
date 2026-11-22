# 差分仕様

## MODIFIED Requirements

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
| INTERFERENCE | 行動選択 |
| INTERFERENCE | 攻撃対象選択 |
| INTERFERENCE | 回復対象選択 |
| INTERFERENCE | 閉塞してWAIT可能 |
| INTERFERENCE | RESULTの背後 |
