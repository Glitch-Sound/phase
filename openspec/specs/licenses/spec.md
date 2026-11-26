# licenses Specification

## Purpose

プレイヤーが配布先のHTMLや外部通信に依存せず、同梱素材とGodotの権利表示およびライセンス原文をゲーム内で確認できるようにする。
ゲームのHELPと権利表示を分離し、通常版とWeb版で同じ文書を提供する。

## Requirements

### Requirement: REQ-063 - 同梱ライセンスの閲覧

WHEN プレイヤーがSETTINGSのLICENSESを開くとき、ゲームはLucideのLICENSEとNOTICE、使用版GodotのMIT原文と第三者COPYRIGHTおよび出典、Noto Sans JPのOFLと出典、自作汎用コードの限定許諾範囲とMIT原文を、外部通信やHTMLに依存せず選択して末尾まで読める形で表示し、原文を翻訳せず、閲覧の終了で編成と未適用の設定を変更せず元のSETTINGSへ戻らなければならない(SHALL)。

#### Scenario: REQ-063-S01 - 原文の選択と閲覧

- **GIVEN** 英語または日本語のSETTINGS
- **WHEN** LICENSESを開いて文書を選択する
- **THEN** LucideのLICENSEとNOTICE、GodotのLICENSEとCOPYRIGHTと出典、Noto Sans JPのOFLと出典、自作汎用コードの限定許諾範囲とMIT原文の全9文書を選べ、選んだ原文が省略されず末尾までスクロールして読める
- **AND** 案内だけが説明言語に従い、ライセンス原文は変化しない

#### Scenario: REQ-063-S02 - 設定へ戻る

- **GIVEN** 未適用の配色を変更してからLICENSESを開いた状態
- **WHEN** BACKまたはEscを入力する
- **THEN** 同じ未適用の配色を保つSETTINGSへ戻り、編成と保存データを変更しない

### Requirement: REQ-064 - 配布物の権利表示

WHEN Web Demoを書き出すとき、配布物は閲覧対象の全9文書をPCKに原文のまま含め、Webページのアイコンとスプラッシュに既定のGodotロゴを使わず、ゲーム内閲覧をHTMLから独立して提供し、既存のNoto表記、使用する5音、未使用2音の除外とデモの保存禁止を維持しなければならない(SHALL)。

#### Scenario: REQ-064-S01 - HTMLとPCKの配布内容

- **GIVEN** 使用版の公式原文と既存のWeb Demoプリセット
- **WHEN** Web Demoを再書き出しする
- **THEN** PCK内の全9文書はソース原文と一致し、使用中5音が存在して未使用2音とそのインポートは存在せず、HTMLと出力画像は既定Godotロゴを参照または表示しない
- **AND** PCKだけの実行でもLICENSESを閲覧でき、SAVEとLOADは無効のままとなる

### Requirement: REQ-065 - 自作コードの限定許諾

公開ソースと配布物は、ui/panel_probe.gdとscripts/lint.mjsだけを自作汎用コードのMIT対象としてパスで明示し、対象ファイルの権利表示とMIT原文を保持し、PHASE固有のゲームロジック、シナリオ、ロゴを含む他の自作ファイルへ許諾を広げず、第三者の既存許諾を維持しなければならない(SHALL)。

#### Scenario: REQ-065-S01 - 適用範囲の識別

- **GIVEN** 公開候補のソースと同梱の権利表示
- **WHEN** README、対象ファイルの表示とライセンス範囲を確認する
- **THEN** 自作MITの対象がui/panel_probe.gdとscripts/lint.mjsの2ファイルだけと明示され、MIT原文と対象ファイルの表示があり、他の自作ファイルの権利留保と第三者の元の許諾が区別される
