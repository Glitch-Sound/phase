# 差分仕様

## MODIFIED Requirements

### Requirement: REQ-042 - 共通の構成選択

WHEN BUILDでCLASS、ARMS、GEAR、各MUTATION、スキルまたはOPERATIONを選ぶとき、共通ダイアログは現在と候補を区別して実際のリングや効果をプレビューし、確定まで構成を変更せず、取消とキーボード操作を許可し、未解放候補を非活性で見せ、装備を能力値で絞り込んでスクロール可能にし、変異を装備との全組合せへ平坦化しないようにしなければならない(SHALL)。

#### Scenario: REQ-042-S01 - 候補と確定と取消

- **GIVEN** 現在装備と異なる開放済みの候補
- **WHEN** 候補を選んで確定または取消する
- **THEN** 選択中は原本を変えず実リングと5値を比較でき、確定時だけ対象の値を変更し、取消とEscは選択前の構成を保つ

#### Scenario: REQ-042-S02 - 全候補と非活性と絞り込み

- **GIVEN** 一部または全解放の共有一覧
- **WHEN** 装備と変異、CLASS、スキルの候補を調べる
- **THEN** ARMSとGEAR各126、変異とCLASS各120、全16スキルの候補を別一覧で確認でき、未解放と他枠で装備済みのスキルは確定できず、装備の指定能力値の下限に合う候補だけへ絞り込め、一覧の先頭と末尾へ到達できる

#### Scenario: REQ-042-S03 - クラスと変異の違い

- **GIVEN** 同じ配置コードのCLASS、GEARまたはARMSの変異
- **WHEN** 各候補を比較する
- **THEN** CLASSはCOREだけ、変異は選んだ装備リングだけの順を示し、配分と他リングを変更しない

#### Scenario: REQ-042-S04 - スキルと作戦の内容

- **GIVEN** 3スキル枠と4作戦
- **WHEN** スキルまたは作戦を選ぶ
- **THEN** スキルは同系統のまとまりと簡潔な説明、対象位置を示し、NONEを許可し、作戦は内容と勝利目的、配置を示し、確定後だけ対象枠または作戦へ反映する

#### Scenario: REQ-042-S05 - モーダルの入力境界

- **GIVEN** BUILDから開いた候補一覧
- **WHEN** キーボードで候補を移動し、確定または取消して閉じる
- **THEN** 有効な候補と操作だけへフォーカスでき、背景の構成や戦闘を操作せず、現在装備と候補を識別でき、閉じた後は呼出元へフォーカスが戻る

## ADDED Requirements

### Requirement: REQ-045 - COREの配置選択

WHEN CLASSを選ぶとき、利用者はVIT、INF、RES、SPD、LUKを一度ずつ並べた120配置を確認でき、VIRSLとVLSRIは常時、それ以外は共有MUTATIONの解放に従って選べ、COREだけの基準配置へ反映しなければならない(SHALL)。

#### Scenario: REQ-045-S01 - 候補と解放の境界

- **GIVEN** 通常の新規一覧、共有変異LSRIVの解放、全解放の一覧
- **WHEN** CLASSを選んで確定する
- **THEN** 候補の全体は重複のない120配置であり、選択可能な集合は新規ではVIRSLとVLSRIだけ、LSRIV解放後はこの2つとLSRIVだけ、全解放では120配置すべてとなり、未解放と不正な配置は確定できない
- **AND** CLASSだけのVLSRI利用によって装備の変異を解放しない

#### Scenario: REQ-045-S02 - 配置と回転とリセット

- **GIVEN** CLASSをLSRIVにしたユニットとCORE回転パネル、RESETを含む経路
- **WHEN** 経路を予測して確定し、RESETを踏んで再戦する
- **THEN** COREの領域順はLUK、SPD、RES、INF、VITとなり、GEARとARMSの順と能力値は変わらず、予測と確定の領域が一致し、RESETと再戦ではLSRIVの戦闘開始時CORE配置へ戻る
- **AND** 通常移動のCORE保持、特殊パネルのCORE回転量とGEAR、ARMSの通常回転、CPUと強制移動の規則は変わらない

#### Scenario: REQ-045-S03 - 旧クラスと保存境界

- **GIVEN** STANDARDとREVERSE、および装備と収集を持つ従来の有効な通常セーブ
- **WHEN** 読み込み、その後に隔離先へ明示保存する
- **THEN** STANDARDはVIRSL、REVERSEはVLSRIの従来と同じCORE配置を再現し、元の装備と収集を維持し、読込元のバイト列を変えず、新しい開放済みCLASSも保存と読込で保持する
- **AND** 不正または未解放のCLASSを含む読込は現在の構成を変えず拒否する

#### Scenario: REQ-045-S04 - 配置コードと対象リングの表示

- **GIVEN** 標準と非標準のCLASS、GEARとARMSのMUTATION、最小と標準の対応画面
- **WHEN** BUILD、選択ダイアログ、戦闘の関連情報とHELPを確認する
- **THEN** 配置コードを主表示とし、初期配置VIRSLには括弧を使わず小さくSTANDARDを添え、CLASSがCORE、MUTATIONが選んだ装備に作用することと解放条件を英語で確認でき、コードと補足が重ならず選択と取消を操作できる
