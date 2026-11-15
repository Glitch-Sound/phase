# battle-interface Specification

## Purpose

一画面の予測情報と明確な入力案内によって移動と位相の関係を理解できるようにし、ビルドから結果までの操作を完結させる。

## Requirements

### Requirement: REQ-017 - オーバーレイ循環

ゲームは起動時に戦闘画面へBUILDを重ね、BATTLE、RESULT、BUILDを反復し、結果へ勝敗と新開放一覧を表示しなければならない(SHALL)。

#### Scenario: REQ-017-S01 - 一巡

- **GIVEN** ゲーム起動直後
- **WHEN** ビルドから戦闘を開始し勝敗を決めて戻る
- **THEN** BUILD、戦闘、結果、BUILDの順に表示される

### Requirement: REQ-018 - 経路入力表示

画面は経路番号、ノード間の線、シアン終点、対象範囲、有効対象、選択、ホバーを表示し、画面案内で最終セルのダブルクリックを知らせなければならない(SHALL)。

#### Scenario: REQ-018-S01 - 経路操作

- **GIVEN** 移動状態の戦闘画面
- **WHEN** 経路追加、取消、ダブルクリック、対象選択を操作する
- **THEN** 番号と終点が追随し、行動選択とBACKが動作する

### Requirement: REQ-019 - 情報と位相予測

画面はHP陣営合計、予定手番、選択ユニット詳細と全スキル、経路後リング、PATHとDESTINATION、同じ角度空間の4波形、最終同期と特異点を表示しなければならない(SHALL)。

#### Scenario: REQ-019-S01 - 情報の比較

- **GIVEN** 異なる位相になる2経路
- **WHEN** 経路を切り替えて別ユニットを調べる
- **THEN** 予測は手番ユニットを維持し、右詳細は選択ユニットへ切り替わり、波形と数値が配置を反映する

### Requirement: REQ-020 - システム操作

画面はHELP、SETTINGS、RESTART、QUITを備え、HELPで操作を説明し、設定でウィンドウとフルスクリーンを切り替え、RESTARTでBUILDへ戻らなければならない(SHALL)。

#### Scenario: REQ-020-S01 - システムメニュー

- **GIVEN** 起動したゲーム
- **WHEN** 各メニューを操作する
- **THEN** HELPが開閉し、表示モードが変わり、RESTARTでBUILDに戻り、QUITで終了する

### Requirement: REQ-021 - 効果フィードバック

WHEN 効果が実行されるとき、画面はダメージを赤の負数、回復を緑の正数、撃破をDEFEATEDとして対象付近から上昇しフェードする表示にしなければならない(SHALL)。

#### Scenario: REQ-021-S01 - 効果表示

- **GIVEN** 負傷と撃破と回復が起こる戦闘
- **WHEN** それぞれのスキルを使用する
- **THEN** HP変化と対応する符号、色、DEFEATEDを表示する

### Requirement: NREQ-001 - 画面寸法

Godot 4.7系の1920x1080基準画面は画像なしで中央3ペインと下部予測を表示し、10x10マップの各セルを70x70として全ユニットをセル内に収めなければならない(SHALL)。

#### Scenario: NREQ-001-S01 - 基準レイアウト

- **GIVEN** 1920x1080と1440x810ウィンドウ
- **WHEN** 各画面を表示する
- **THEN** マップ全体、右情報、下部予測、フッターが重ならず操作できる
