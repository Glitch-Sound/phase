# 説明文の英日切り替えの検証

## 変更内容

基準は51c8495で、開始時の作業ツリーは変更なしであった。
SETTINGSへLanguageを加え、System、English、日本語を選べるようにした。
Systemと未知、未設定は日本語系の優先言語だけ日本語、それ以外は英語を選ぶ。
明示のenとjaを環境より優先し、画面を再起動せず説明だけを更新する。

言語は配色パスに.language.jsonを付けた独立ファイルへ保存する。
既定ではartifacts/runtime/ui-settings.json.language.jsonのlanguageがsystem、en、jaのいずれかになる。
既存の配色配列は変換せず、読込だけで設定を書き換えない。
書込に失敗した場合は以前の選択と表示を保つ。
全解放中は一時的な選択だけを使い、通常設定を保存せず、終了時に通常の言語へ戻す。

対訳はui/japanese.gdの153件へ集約した。
表示層で明示した説明だけを翻訳し、モデルの原文、タイトル、見出し、スキル名、装備名と機械的なラベルは維持する。
言語選択の日本語という表記は、英語モードでもそのまま表示する。
任意の入力名を翻訳せず、名前由来の紋章と所属、内部IDを変更しない。

## 翻訳の範囲

- HELP、SKILLS、FIELDSの本文。
- BUILDの名前と配分、装備比較の案内、CLASS、MUTATION、SKILLとOPERATIONの候補説明とツールチップ。
- 戦闘右欄のMOVEと各スキルの説明、パネル効果、周囲効果の相殺、経路と対象の選択ガイドと通知。
- ASSEMBLYの説明、SETTINGSの説明、配色と保存のエラー、保存と読込の完了通知、報酬がない場合の説明。
- 読み上げ用の確認中ユニットという接頭辞。名前そのものは維持する。

UIで任意の文字列を一括置換せず、登録した説明と書式だけを対応させる。
日本語は簡潔な常体とし、英語の原文は維持した。
音声とSE、戦闘、解放、移動とPREVIEWの計算は変更していない。

## 自動検査

- 先に作った検査は、部品とLanguage選択が未実装の状態で2件失敗した。
- 言語の検査は41件、失敗0である。
  解決、地域と主言語の分離、保存と復元、不正値、書込失敗、全候補の各説明行、即時更新、名前の保持と全解放の保存境界を確認した。
- npm run checkは101組、8255件、失敗0である。
  既存の英語検査はGodotの--language enを明示し、言語の検査をプロダクト検査へ加えた。
  バランスに依存する固定期待値は加えていない。
- カタログの説明は行単位でも未翻訳を検査し、一部だけ訳せていれば成功とする判定を避けた。
- ゲーム状態の保持は編成と名前、経路、選択、手番、HPとリングの完全一致で確認した。

## 起動と保存の確認

実機のOSとGodotのロケールはいずれもja_JPで、未設定のSystemから日本語で起動した。
OSの言語と地域の設定は変更していない。
以下はOS設定を変更せず、隔離したアプリの起動ロケールで検証した。

| 起動ロケール | 保存値 | 結果 |
| --- | --- | --- |
| ja_JP | 未設定 | 日本語 |
| en_JP | 未設定 | 英語 |
| en_US | ja | 日本語 |
| ja_JP | en | 英語 |
| en_JP | 未知 | 英語 |
| ja_JP | 言語項目なし | 日本語 |

ja、ja-JP、ja_JP、ja_Jpan_JPの判定と、日本語以外の主言語も部品で確認した。
英語と日本語、Systemを保存して新しい読込で復元し、別のUI起動でも保存した英語が日本語環境に優先した。
通常の配色ファイルとビルドの保存は作成していない。

## 実描画と識別の保持

Apple M4、Godot 4.7.2、Compatibilityで275件、失敗0であった。
1920x1080と1152x648でHELP、SKILLS、FIELDS、BUILD、CLASS、MUTATION、SKILL、OPERATION、Languageを表示した。
3種類のCOREパネルも日本語で表示した。

HELPの初回表示で移動と読み方の説明が縦にはみ出したため、移動の日本語を整理し、文字サイズを維持して日本語本文の行間だけを調整した。
最終表示で段落の必要高が既存の割当へ収まり、禁則と折り返しを確認した。
既存のHelvetica Neueとシステムの日本語フォールバックを維持し、外部フォントは追加していない。
文字収録は優先フォントだけのhas_charではなく、実際に組版されたフォールバック後の実グリフで確認した。
折り返し用の仮想空白は実グリフの判定から除いた。
行内の紋章の領域が直径より小さい場合を先行検査で検出し、文字組みの領域を直径以上にして欠けを防いだ。

全解放の隔離3対3を合法な7行動で進め、TURN 08、2歩の予測経路、INF 200%の同一場面を使った。
表示中の味方名はLumen、所属名はAXISである。
各サイズで同じ状態のままEN、JA、ENと往復し、右欄は次のように変わった。

| 表示 | 英語 | 日本語 |
| --- | --- | --- |
| 名前に相当する表示 | 同じ紋章 | 同じ紋章 |
| 移動ラベル | MOVE 3 | MOVE 3 |
| 移動説明 | Move up to 3 cells per turn. | 1手で最大3マス移動。 |
| スキル名 | DAMAGE / ADJACENT等 | DAMAGE / ADJACENT等 |
| スキル説明 | 英語の既存文 | 対応する日本語の説明 |

盤面全体と右のユニット紋章の実ピクセルのSHA-256が、EN、JA、ENの3回すべてで一致した。
言語だけの変更で、識別、所属と戦闘の状態が変わらないことをデータと実描画で確認した。
終了時は全解放を解除し、通常BUILDと元のコレクションへ戻して検証アプリを終了した。

## 画像と添付の状態

ゲーム画面だけの新規PNGを3枚用意し、実画像を確認した。
個人情報とデスクトップは含まない。

- HELP: artifacts/runtime/bilingual-explanations/phase-language-help-ja-1920x1080.png
- Language: artifacts/runtime/bilingual-explanations/phase-language-settings-ja-1920x1080.png
- MOVE 3の戦闘: artifacts/runtime/bilingual-explanations/phase-language-battle-ja-1920x1080.png

Libraryへの保存は自動承認レビューが拒否したため、添付用IDは未取得である。
本人の今後もUI改修後のキャプチャを送ってほしいという依頼を確認して再試行したが、保存先がChatGPT Libraryであることの明示承認がないと判断された。
送信は開始されておらず、別経路での保存は行っていない。
承認後はこの3枚の保存だけを再開できる。

## 仕様との照合

| 観点 | 結果 |
| --- | --- |
| 完全性 | 6タスク、1追加要件、1変更要件、6シナリオを確認した |
| 正確性 | 言語の部品とUI接続、英語の既存検査、日本語の開発時描画を確認した |
| 一貫性 | D-01の説明だけの対訳、D-02の独立設定、D-03の即時更新と組版が実装に一致する |
| 指摘 | 実装と検査のCRITICAL、WARNING、SUGGESTIONはなし |

Libraryの保存は実装の検査とは分け、成果物の未完了事項として残す。

## 未確認と限界

表示と入力の接続はGodotの実描画とシグナルで確認し、実マウスと実キーボードでの通し操作は未実施である。
iPhoneと他OS、他GPUは未確認である。
利用者の最終判断を残すため、manual-checks.mdのREQ-053-S05は未確認を維持する。

## 参照

GodotのOSロケールは[公式のOS文書](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-locale)と[macOSの実装](https://raw.githubusercontent.com/godotengine/godot/master/platform/macos/os_macos.mm)を参照した。
アプリの現在ロケールは[TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html#class-translationserver-method-get-locale)、段落は[TextParagraph](https://docs.godotengine.org/en/stable/classes/class_textparagraph.html)を参照した。
