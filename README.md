# PHASE

移動経路で装備リングを回転させ、位相の干渉を予測して戦うGodot製の戦術ゲームである。
敵味方とも人が操作する開発用のプレイ可能版であり、敵CPUとレベルはない。

## セットアップ

### 必要なもの

- Godot 4.7系(検証版4.7.2、Mac arm64)。
- 開発検査にはNode.js 22.12以上とnpm、Git。
- 追加のGodotアドオンや外部サービスは不要。
LucideのSVGアイコンとライセンスは同梱済みである。

### 手順

1. Godotでproject.godotをインポートする。
2. プロジェクトを実行する(Macの既定ショートカットはCommand+B)。
3. ターミナルからは次のコマンドでも起動できる。

~~~sh
godot --path /Users/glitch/Developer/phase
~~~

## 使い方

起動直後のBUILDでPLAYER 01、02の構成とステージを選び、BATTLE STARTを押す。
アクセント色の円で示した手番ユニットから、空いた上下左右のセルを順にクリックする。
PHASE PREVIEWで移動後のリングと同期補正を比較し、経路の終点をダブルクリックして確定する。
WAITまたは装備したACTIVEを1つ選び、有効対象をクリックする。
敵の手番も同じように自分で操作する。

- 経路上のセルをクリックすると、それ以降を取り消す。
- 開始セルまたはEscで未確定経路を消す。
- BACKは確定した移動を保持して行動選択へ戻る。
- 生存ユニットの通過、斜め移動、経路の再進入はできない。
- 毎手番の移動は必須であり、四方を塞がれたときだけ無移動WAITができる。
- 別ユニットまたは手番一覧をクリックすると右側の詳細を調べられる。
- RESTARTは現在戦闘を破棄してBUILDへ戻る。

### ステージ

| ステージ | 勝利条件 | 役割 |
| --- | --- | --- |
| INTERFERENCE | ENEMY全滅 | 基本戦闘と経路比較 |
| SEVERANCE | 敵Aを撃破 | 01を守り、02で敵Bを遮る |
| BREACH | 01が(9,0)へ移動を確定 | 01を守り、守備役Aを突破し、Bの(0,9)到達を阻止する |
| ANCHOR | PLAYERが(8,0)を占有して手番終了 | 守備役Aを退け、ENEMYの(0,9)占有を防ぐ |

いずれもPLAYER全滅で敗北する。
SEVERANCEとBREACHは01の撃破でも直ちに敗北する。
後半2ステージは赤のLOSS目標を相手に達成されても敗北する。
敵を全滅させただけでは終わらず、指定目標の達成が必要である。
勝利と敗北が同じ判定時機に成立した場合は敗北を優先し、一度確定した結果は変わらない。
初期01はSPD30のランナー、02はCOREと装備のINF30を持つ迎撃役である。
敵は手動で操作するため、目標へ急ぐか攻撃するかもプレイヤーが選ぶ。

### パネルと位相

| 表示 | 効果 |
| --- | --- |
| 無印 / NORMAL | GEAR反時計、ARMS時計回り |
| S+ / SHIFT | ARMSだけ通常の2倍回転 |
| L= / LOCK | GEARだけ回転しない |
| R- / REVERSE | ARMSだけ逆回転 |

COREは回転しない。
赤はINF、緑はRES、青はSPD、黄はLUK、灰はVITを示す。
表示するINF/RES SYNCはベルカーブ適用後の効果補正であり、最大200%である。
生の重なり率、LUK補助後の中間値とは異なる。
SINGULARITYは生INFセクターが完全一致し、CORE:INFが10以下のときだけ成立する。

### ビルドと保存

COREを変更すると他の値を再配分し、全値1以上、合計100を維持する。
STANDARDとREVERSEはCOREの配置順を変える。
装備と開放した変異は全PLAYERで共有し、同じものを複数人へ装備できる。
スキルは最大3個、未設定も許可する。
DAMAGEとHEALは初期開放し、MOVE+1は戦利品で取得する。
取得後は両PLAYERで共有できる。
既存セーブの開放済み3スキルはそのまま使える。
装備の型番の下には5ステータスを十進表示し、変更直後は前の装備との差分を表示する。
候補をポイントすると現在装備との差分も確認できる。

SAVEはビルド、開放一覧、ステージを作業先のartifacts/runtime/phase-save.jsonへ保存する。
再保存時は元のファイルを別名の.backup.jsonとして残す。
LOADは明示操作で行い、破損や未知の版は現在データを変えずに拒否する。
戦闘途中のセーブと自動セーブはない。
検証時に取得した装備を含むセーブがあるが、起動時には自動読込しない。

### 表示設定

HELPに日本語の操作説明がある。
SETTINGSでウィンドウ、フルスクリーン、波形の動きを抑えるREDUCED MOTIONを選べる。
1920x1080の内容全体を16:9のまま画面へ合わせ、異なる縦横比では上下または左右に余白を置く。
RetinaでもOSの倍率を重ねず、文字と盤面とリングとオーバーレイを同じ比率で拡縮する。

Godotから実行して全画面でも小さい場合は、ゲームビューの右上のメニューでFixed SizeからKeep Aspect Ratioへ変更する。
この作業先はプロジェクト別の生成メタデータで変更済みだが、.godotを作り直した場合や新規インポート時は選び直す。
ゲームバーの表示寸法がウィンドウの拡大に応じて増えることを確認する。
今回の実画面では固定の1440x810から4442x2499へ増えた。

埋め込み中は外側のゲームビューを拡大する。
ゲーム内SETTINGSのFULLSCREENを使う場合は、Embed Game on Next Playを無効にして再実行するか、上記のgodot --pathコマンドで独立実行する。
これは[Godotの埋め込み表示の制約](https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html)である。
表示と入力の検証結果は[表示追従の記録](artifacts/display-verification.md)を参照する。

## 検証

~~~sh
npm ci --ignore-scripts
npm run check
~~~

Godotだけの検証は次のコマンドで行う。

~~~sh
godot --headless --path . --script tests/run.gd
godot --headless --path . --script tests/playthrough.gd
godot --headless --path . --script tests/review_regressions.gd
godot --headless --path . --script tests/contested_play.gd
godot --headless --path . --script tests/display_flow.gd
~~~

初版の検証は[初版検証記録](artifacts/verification.md)、レビュー後の修正と28手の実操作は[追加検証記録](artifacts/review-verification.md)に区別して記録する。
仕様の対応は[仕様書一覧](openspec/specs/README.md)、ユーザーの最終確認は[実機確認表](openspec/manual-checks.md)を参照する。

制限されたシェルではGodotの標準ユーザーデータディレクトリとシステム証明書の初期化が拒否され、エンジンの警告が出る。
ゲームの保存はそのディレクトリを使用しない。
スクリプトエラーやテスト失敗は検査を失敗させ、既知のホスト権限警告とは区別する。

## 開発

指定テンプレートGlitch-Sound/openspec-templateの0.1.1、commit 3224955f87122339c8961563c6d964d90a7c8521を導入した。
OpenSpec 1.16.0をpackage-lock.jsonで固定する。

### OpenSpecの設定

マシン全体の設定を変更せず、プロジェクト内のキャッシュへ隔離する。

~~~sh
export XDG_CONFIG_HOME="$PWD/.tool-cache/config"
export XDG_DATA_HOME="$PWD/.tool-cache/data"
export OPENSPEC_TELEMETRY=0
npx --no-install openspec config set profile custom
npx --no-install openspec config set workflows '["explore","ff","apply","update","verify","sync","archive"]'
npx --no-install openspec config set delivery skills
npx --no-install openspec init --tools codex
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
~~~

プロダクト検査はscripts/check.sh、仕様とトレースの検査はscripts/check-specs.shが担当する。
コミット前のフックがnpm run checkを実行する。
生成されたOpenSpecスキルは手で編集しない。
GitHubへのpushとゲームの公開は行っていない。

## 配色とUI

minimal dark intelligenceを方針とし、黒い面、位相リング、4波形、HPと同期の棒で情報を伝える。
装備の5値、型番、変更差分、効果量と符号は保持する。
SETTINGSでDEFAULT、AMBER、ICEを選ぶか、6個の色見本でアクセントと5ステータス色を編集する。
APPLY COLORSで適用し、CLOSEまたはEscでは未適用の配色を取り消す。
暗すぎる色や区別しづらいステータス色は理由を表示して拒否する。
UI設定はartifacts/runtime/ui-settings.jsonへ保存し、既存設定はbackup付きで退避する。
ビルド保存とは独立しており、SAVEとLOADの操作は従来どおりである。
TabとShift+Tabは最前面の操作部品を移動し、Enterで実行する。
Lucideの出典とISCおよびFeather由来MITの権利表示は[NOTICE](assets/lucide/NOTICE.md)と[LICENSE](assets/lucide/LICENSE)にある。

UIだけを再現する検証ラボは次で起動する。
戦闘難易度を検証するモードではなく、本体の起動シーンにも組み込まれない。

~~~sh
godot --path . --script tests/visual_lab.gd --resolution 1440x810
~~~

F2は勝利と0件、F3は敗北と2件の表示fixture、F4は回復対象、F5は攻撃対象、F6は行動選択、F10はartifacts/runtimeへの画面保存である。
表示確認ではラボ専用の配色設定を使い、通常のビルドセーブには触れない。
