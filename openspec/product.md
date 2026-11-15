# プロダクト

## 目的

移動経路を設計し、位相の干渉を予測して戦うゲームを実現する。
入力は /Users/glitch/Developer/phase-input/requirements.md、SHA256はebd39aaf10e80b0c5e188be3acd9f4e397cf6f111103e3ff5b422064b7501bf6である。

## 対象範囲

### 対象

- 両陣営を人が操作する戦術戦闘。
- 決定的な計算、経路予測、ビルド、収集、保存。
- minimal dark intelligenceに基づく黒いUIと設定可能な配色。画像は同梱したLucideアイコンだけを使う。
- 実プレイと自動検証に基づく報告。

### 対象外

- 敵CPU、レベル、通信、公開、未定義の周囲と直線スキル。

## 用語

| 用語 | 意味 |
| --- | --- |
| RAW SYNC | LUK補助なしの三重重なり率 |
| ASSISTED SYNC | LUKとペア干渉を含む中間値 |
| INF/RES SYNC | ベルカーブ適用後の最終補正 |
