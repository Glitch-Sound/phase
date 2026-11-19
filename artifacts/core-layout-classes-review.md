# CORE配置とBUILDの間隔の検証

## 変更と選択した規則

CLASSはMUTATIONと同じ120配置からCOREの基準配置だけを選ぶ。\
VIRSLと従来のREVERSEに相当するVLSRIは常時選択可能とし、他の118配置は共有MUTATIONの解放を使う。\
CLASSのVLSRI利用によって装備のVLSRIを解放せず、ドロップと装備側の条件は変えていない。\
全解放ではCLASSも全120配置を試せる。

表示は配置コードを主とし、VIRSLへ小さくSTANDARDを添えた。\
BUILD、CLASSと装備MUTATIONの共通ダイアログ、戦闘右情報とHELPを英語で揃えた。\
CLASSはCORE、MUTATIONは指定装備だけに作用すると説明する。\
確定までは複製を描き、取消では元の構成を維持する。

COREの順だけを追加し、通常移動でのCORE保持、特殊パネルの回転量、GEARとARMSの通常回転、角度とRESET、戦闘式は変えていない。\
選択した並びは戦闘中に固定されるため、RESETが開始角へ戻れば、そのCLASSの開始時配置へ戻る。\
敵の初期構成を任意CLASSへランダム変更していない。

旧STANDARDはVIRSL、REVERSEはVLSRIの同じ順として計算する。\
旧別名、装備と収集を保持し、読込元を自動移行しない。\
新しく確定したCLASSはコードを保持し、既存と同じ明示保存だけで書き込む。\
保存形式へ新しいフィールドは追加していない。

UNLOCK ALLとENEMY CPUはクリック領域と右端を維持し、ラベルを右へ寄せた。\
ラベル、ON/OFF、スイッチの間隔はそれぞれ8とし、ON/OFFの最大文字幅を予約する。\
標準座標ではラベル末尾からスイッチまで約41となり、項目同士の見える間隔より小さい。\
ユニット選択との余白、STARTのアイコンとラベルの中央揃え、リリース条件でのCPU右寄せを維持した。\
調整値はgame/tuning.gdにある。\
Godotの内部余白と配置は[公式実装](https://github.com/godotengine/godot/blob/master/scene/gui/check_button.cpp)と実描画で確認した。

## 検証結果

| 検査 | 結果と証拠 |
| --- | --- |
| 構成モデル | 追加前31項目中9失敗、実装後31項目成功。class-layout-model-red.txtとclass-layout-model-green.txt |
| 共通ダイアログ | コード表示の追加前35項目中2失敗、実装後35項目成功。class-layout-ui-red.txtとclass-layout-ui-green.txt |
| トグル配置 | 修正前30項目中2失敗。最終の共通ダイアログ検査に含めて成功 |
| 戦闘右情報 | 91項目成功。class-layout-info-green.txt |
| BUILDと保存の接続 | 365項目成功。class-layout-hierarchy-green.txt |
| 文字削除の厳密検査 | 114項目成功。新しいコードとSTANDARD補足だけを期待集合へ反映し、余分な文字数も検出する。class-layout-labels-green.txt |
| 全体検査 | npm run check成功。全プロダクト検査、5仕様、トレースを含む。class-layout-check-complete.txt |
| 仕様とトレース | openspec validate core-layout-classes --strictとopenspec-traceのstrict検査が成功 |
| 実GPU | 最終コードで1152x648と1920x1080、30項目成功。core-layout-gpu-final.txt |
| 実リリース | 最終コードの検証用書き出しで5項目成功。core-layout-release-check.txt |
| 差分 | git diff --check成功 |

ログの場所はartifacts/runtimeである。\
新しい検査ファイルと検査コマンドは増やさず、既存の構成とUIの検査を拡張した。\
既存のCLASSが2候補だけである期待、旧表示の完全一致と文字数の期待は、利用者が承認した振る舞いに対応して更新した。\
HELPのユニット番号案内は既存検査で抜けを検出し、検査を変えず案内を維持した。\
保存の期待は独立した入力データをJSONとして比較し、JSON数値の整数と小数の表現差だけを正規化した。\
旧読込、回転とRESETの機構は既に存在するため、その部分は追加前にも成功した。\
勝敗、終了手数、固定戦術の回復量の期待は追加していない。

## 実画面と操作

Apple M4、Godot 4.7.2、Compatibility、OpenGL 4.1 Metalの実描画を画像で確認した。\
最小と標準で、標準配置のコードと小さい補足、非標準CORE、装備変異との区別、HELPの5行、スイッチの間隔とリリース相当の非表示を確認した。\
GUIへ変換した入力イベントでCLASSを開き、末尾へ移動して確定、装備MUTATIONを取消、START、CORE回転、経路再選択、RESETと通常BUILDへの復帰を確認した。\
トグルだけの実GPU検査では、元のクリック領域の左端とスイッチ本体からの入力も確認した。\
これらはGodotのGUI入力であり、OSの物理マウスを使った自然な手動対戦とは区別する。\
検証用Godotは通常BUILDへ戻してから終了した。

画像は次のローカルファイルにある。\
各画像はゲームの描画領域だけであり、デスクトップと個人情報を含まない。

- artifacts/runtime/core-layout-build-1920x1080.png
- artifacts/runtime/core-layout-build-1152x648.png
- artifacts/runtime/core-layout-class-standard-1920x1080.png
- artifacts/runtime/core-layout-class-nonstandard-1152x648.png
- artifacts/runtime/core-layout-mutation-standard-1152x648.png
- artifacts/runtime/core-layout-battle-reset-1152x648.png
- artifacts/runtime/core-layout-help-1152x648.png

## OpenSpecの検証

core-layout-classesをff、apply、verify、archiveの順で完了し、正式仕様へ同期した。\
アーカイブはopenspec/changes/archive/2026-11-19-core-layout-classesにある。

| 観点 | 結果 |
| --- | --- |
| 完全性 | 7タスク完了、変更REQ-042と追加REQ-045の全9シナリオを確認した |
| 正確性 | 8シナリオは既存のモデルと共通UI検査、REQ-045-S04は実GPU画像とGUI入力で開発側の観測を行った |
| 一貫性 | D-01からD-04に対応し、モデルから画面への依存と保存境界を維持した |

CRITICAL、WARNING、SUGGESTIONはない。\
候補数だけでなく有効な文字集合と重複、選択可能集合の完全一致を確認し、旧2候補の実装が新しい期待を満たさないことを先に検出した。\
表示の完全一致と総文字数も維持し、コードの接頭辞や不要な別名だけが残る誤りを見逃さない。\
利用者の最終確認はmanual-checks.mdのREQ-045-S04を未確認のまま残す。

## 保存境界と限界

実セーブphase-save.jsonのSHA256は25167e282e85b12fd9f059ae72d9cb16e4d6fb55310b1d3f57295dd02a6573e2、更新時刻は1794705159636683302であり、作業前と同じである。\
ui-settings.jsonは未作成のままである。\
検証は使い捨ての保存先を指定し、通常データと全解放の分離を維持した。

全120配置と全配分、全ステージの自然な対CPU戦を網羅していない。\
新しい配置が戦術と同期へ与えるバランスは継続評価の対象であり、今回威力式は調整していない。\
既存の撮影補助unit_information_captureの旧クラス名比較もコード表示へ更新したが、その過去の撮影手順全体は再実行していない。\
全体検査が案内する既存の実機未確認18件と今回の利用者確認1件を完了へ変えていない。\
push、公開と画像アップロードは行っていない。
