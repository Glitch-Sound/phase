# 全解放と10刻みの検証

最新の確認は末尾の再開後の検証に記録する。\
実装コードは644183aから変更していない。

## 初回の中断状態(644183a時点)

実装と全体検査は完了したが、実画面操作の最終確認は完了していない。\
MacのロックによりGodotへ接続できず、REQ-041-S05とtasksの3.2、4.1は保留とする。\
strict差分は成功し、strictトレースはこの2件の未完了を正しく検出する。\
アーカイブは実施しない。

## 変更

新規ARMSとGEARの5値を各10以上の10刻み、合計100とした。\
10単位の正整数5個の和10を区切るため、配分数はC(9,4)=126となる。\
共通catalogから通常の戦利品と全解放を生成し、変異の共通解放、重複の再抽選と戦闘式は維持した。

ニューゲームの初期装備4配分のうち、20、30、15、20、15を20、30、10、20、20へ、25、15、20、30、10を30、10、20、30、10へそろえた。\
COREの自由配分は変更せず、旧セーブの変換と移行は実装しない。\
全体検査が生成するcontested-play.jsonとpanel-play.jsonの被ダメージ観測も、この初期装備変更に従って更新された。\
勝敗やダメージの固定期待値は追加していない。

デバッグBUILDのUNLOCK ALLから、新規の一時collectionでARMSとGEAR各126、NORMALを含む120変異と全16スキルを使える。\
通常collectionは別参照で保持し、SAVEとLOADをUIとデータ層で拒否する。\
戦利品と乱数の消費を止め、配色はメモリ内だけへ適用し、EXIT DEBUGで通常の構成、ステージ、配色と動き、CPU設定と乱数を復元する。\
RESTARTでは一時モードを維持し、再入場時は新規の検証データとする。\
BUILDの既存3列と選択方式は維持した。

## 自動検証

| 検査 | 結果と証拠 |
| --- | --- |
| 既存戦利品のRED | 10刻みの強化後に514検査中171失敗。artifacts/runtime/unlock-red-run.txt |
| 新規下層のRED | 未実装で3検査中3失敗。artifacts/runtime/unlock-red-debug_unlock.txt |
| UI接続のRED | 未実装の切替で失敗。artifacts/runtime/unlock-red-ui.txt |
| 保存しない通知色の復元 | 既存の復元期待を強めて11検査中1失敗を確認後に修正し、11検査中0失敗。artifacts/runtime/unlock-notice-red.txt、unlock-notice-green.txt |
| 下層の全解放 | 17検査中0失敗。独立した全126集合、全変異とスキル、通常参照、再入場、ファイルと乱数の境界 |
| UI接続 | 11検査中0失敗。入口、保存不可、設定の一時適用、RESULT、再開始と退出 |
| 誤実装の検出 | 候補欠落、一時戦利品と一時ファイル処理の3誤実装がすべて失敗。artifacts/runtime/unlock-mutants.json |
| 全体 | npm run check成功。artifacts/runtime/unlock-check-final.txt |
| 正式仕様 | 5仕様がstrict成功。ユーザーの実機確認は従来16件に今回1件を加えた17件を未確認のまま維持 |
| 差分仕様 | npx --no-install openspec validate debug-unlocks-ten-step-loot --strict成功 |
| strictトレース | 未完了3.2と4.1の2件で失敗。合格と扱わない |

プロダクト検査のscripts/check.shへdebug_unlockとdebug_unlock_uiの2スイートを接続した。\
既存の階層検査は、今回追加したデバッグ入口を実際の環境に応じた操作集合へ含めた。\
通常の装備、位相、HP上限、対象、CPUと手番、保存の既存検査は維持した。

## 実際のリリース

インストール済みGodot 4.7.2と同じ公式の書き出しテンプレートのmacos.zipをプロジェクトの.tool-cacheへ取得した。\
追加アプリのインストールは行わず、外部へのpushと公開も行っていない。\
取得元とSHA256は.tool-cache/godot-export-4.7.2/source.jsonへ記録した。

最終productコードを検証専用プロジェクトへ複写し、署名しないローカルのリリースをartifacts/runtime/PHASE-validation.appへ書き出した。\
実際のリリース実行環境で、OS.is_debug_buildが偽、allowedを真にしても下層で拒否、入口不在、UI直接呼出の拒否の4検査がすべて成功した。\
証拠はartifacts/runtime/unlock-actual-release-final.txtである。\
配布署名と公証、別Macでの実行は未検証であり、今回の目的には含めない。

headless起動の証明書初期化警告と、書き出し時のGodot標準エディター設定の保存拒否は、プロダクトの検査失敗と区別した。\
実ユーザーのゲームセーブと配色設定への書込はしていない。

## 実画面と操作の限界

初期のGPU検証で1152x648の実GodotのBUILD画像を取得した。\
DEBUG / NOT SAVED、各126装備と120変異の件数、EXIT DEBUG、無効なSAVEとLOAD、既存の3列が表示され、デスクトップと個人情報を含まないことを画像のピクセルで確認した。\
ただし、この検証の物理フォーカスと選択入力は失敗しており、画像は選択した末尾が正しいことやクリックの合格証拠にはならない。\
画像取得後に通知文字色の復元を修正したため、最終コードのGPU回帰を完了した画像とも扱わない。

画像のローカルパスはartifacts/runtime/debug-unlock-gpu-1795016964.02436-build-1152x648.pngである。\
新規Library画像のIDはlibfile_fde3_f-cb1c632195bc8191acdbf3e9e88ea980_7bf0ff0e6b488191936c99c00c29c4c9である。\
既存Library画像を置換していない。

別の書き出しデバッグアプリPHASEをComputer Useへ渡す経路では、Godotと別アプリとして許可要求が発生し、ユーザーによる中断が返った。\
事前の理由説明より先に許可要求が出たため、この経路は再試行していない。\
許可済みGodotへの接続に切り替えたが、Macがロックされ、自動解除もできない旨が返った。\
ロック解除を依頼し、以降の画面操作を停止した。\
ロック中の描画用Godotは今回起動したPIDだけを終了した。

残る検証は、最小、標準、拡大と縦長での126装備と120変異の先頭と末尾の選択、キーボードと物理フォーカス、クリック、全解放での実戦、通常BUILDへの最終復帰、最終コードのキャプチャである。\
headlessのUI接続とGPUの描画標本、自然な対戦の実プレイを混同しない。\
通常のGodot画面が最終的にBUILDであることは、ロック解除後に再確認する必要がある。

## 実データの保護

全検査は検証専用パスを使った。\
artifacts/runtime/unlock-real-data-before.jsonとunlock-real-data-after.jsonで、実セーブのSHA256と更新時刻、実設定ファイルの不存在が一致した。\
通常の実セーブと設定は保存、削除と上書きを行っていない。

## 初回verifyの照合(644183a時点)

| 観点 | 結果 |
| --- | --- |
| タスク | 6/8完了。3.2の物理操作とGPU回帰、4.1の最終verifyとarchiveが未完了 |
| 仕様の実装 | 変更REQ-015と追加REQ-041の2要件に実装が存在する |
| シナリオ | 7件の自動検査が成功し、1件の実機確認が保留 |
| 設計 | D-01の共通カタログ、D-02の独立した通常参照と必須環境判定、D-03の最小入口と既存選択方式をコードで確認 |
| パターン | モデルはgameへ置き、寸法はtuning、UI接続はmainへ置く既存方針を維持 |

| シナリオ | 実装と検証 |
| --- | --- |
| REQ-015-S01 | catalogの全126配分、collection.roll_loot、runとdebug_unlockの独立集合とドロップ境界 |
| REQ-015-S02 | collection.accept_drop、既存runの重複と変異検査 |
| REQ-015-S03 | main._result、既存review_regressionsの再表示と乱数の不変検査 |
| REQ-041-S01 | debug_session.availableとbegin、main._buildと_toggle_debug、debug_unlockとdebug_unlock_ui、実releaseの4検査 |
| REQ-041-S02 | debug_session.begin、catalogの配分と変異、debug_unlockの全集合と別参照 |
| REQ-041-S03 | collectionの保存と読込、roll_lootの拒否、main._apply_colors、debug_unlockとdebug_unlock_ui、3誤実装検出 |
| REQ-041-S04 | debug_session.end、main._toggle_debug、_restartと_quit、debug_unlockとdebug_unlock_uiの再開始と通常復元 |
| REQ-041-S05 | mainの切替とバッジ、既存OptionButton、tests/debug_unlock_capture.gdの再取得経路。物理操作と最終描画は未確認 |

重大な未完了は上表の2タスクであり、実画面確認を省略して完了へ変更しない。\
実装の欠落と設計の矛盾は確認した範囲で見つからないが、実機のシナリオを合格とは判断できない。\
Macのロック解除後、許可済みのGodotで装備選択と終了を検証し、新規キャプチャとLibrary画像、最終verifyを更新する必要がある。

## 再開後の検証

利用者のロック解除後に、許可済みGodotで最終コード644183aのGPUと入力を確認した。\
プロダクトコードと自動テストは変更していない。\
Godotの実画面を通常BUILDへ戻し、画面操作を終了した。

| 観点 | 実際の結果と証拠 |
| --- | --- |
| ネイティブGPU | 202検査中0失敗。artifacts/runtime/unlock-resume-standalone-gpu-result.json |
| サイズ | 1152x648、1920x1080、2560x1440、縦長1200x1600の要求ウィンドウ。縦長の描画内容は1200x675の16:9で、余白全体の画像検証とは区別する |
| 選択 | 各サイズで126装備と120変異の先頭と末尾、GUARDとFIELD_FAST、開始と対象、再スタートと終了をネイティブ入力で検査 |
| 物理操作 | Godotの埋め込み画面でマウスとキーボードからUNLOCK ALL、ARMSとGEAR末尾、ARMS変異LSRIV、GUARDの装備、STARTを操作 |
| 実戦 | 両陣営を手動操作し4行動完了、TURN 05。移動4回、GUARD1回とDAMAGE3回を実行。リリースやCPUの完全な一戦ではない |
| 通常復帰 | RESTART後も検証装備を保持し、EXIT DEBUGで通常のARMS4、GEAR4、変異1と初期スキルに復帰。normal_unchanged=true、build_open=true、debug=false |
| 実データ | unlock-resume-real-data-before.jsonとunlock-resume-real-data-after.jsonでSHA256、更新時刻と設定の不存在が一致 |
| 全体検査 | npm run check成功。artifacts/runtime/unlock-resume-check.txt |

実戦ではユニット1を(5,4)へ動かしてGUARD、ユニット2を(5,6)へ動かしてBを攻撃した。\
AとBも移動と攻撃を行い、TURN 05ではユニット1のHPが886/900、ユニット2が72/100、Bが81/100となった。\
GUARDの消費と装備の実戦反映を確認した。\
今回の目的は全解放で装備を試せることと復元の確認であり、自然なCPU戦の完走やバランス、別Macの動作は未検証である。

初回の埋め込みドライバーでは202検査中1失敗となった。\
終了時の通常参照の完全復元は成功したが、追加の通常SAVEとLOADの完全一致でJSONの整数から浮動小数への変換差を検出した。\
ネイティブ検証では既に作成した検証専用の保存を読んだ正常な開始状態へ揃え、同じ完全一致の期待を変更せず202検査すべてが成功した。\
プロダクトやコミット対象テストの期待値を緩めていない。\
埋め込みではウィンドウのサイズ要求が描画サイズへ反映されないため、4サイズの合格証拠は別のネイティブGPU検査とした。

## 最終キャプチャ

| 内容 | ローカルパス |
| --- | --- |
| 全解放BUILD、1920x1080 | artifacts/runtime/unlock-resume-standalone-gpu-build-1920x1080.png |
| 物理操作で進めたTURN 05、4442x2498 | artifacts/runtime/unlock-resume-manual-battle-turn05.png |
| 通常へ復帰したBUILD、4442x2498 | artifacts/runtime/unlock-resume-manual-normal-return.png |

各PNGの実ピクセルを見て、全解放の識別と通常復帰、装備と戦闘内容を確認した。\
デスクトップと個人情報を含まない。\
新規画像2枚をLibraryの正式なPythonヘルパーで保存しようとしたが、既定のネットワークではtools/listのDNS解決に失敗した。\
同じ処理のネットワーク許可実行は、自動承認レビューが画像と送信先への明示承認を確認できないとして拒否し、実行されなかった。\
別経路への迂回は行わず、この2枚の新規Library IDはまだない。\
利用者へ、確認済みの全解放BUILDとTURN 05をChatGPT Libraryへ新規保存してよいか具体的な確認を出した。

## 最終verify

前表の8シナリオの対応を再照合した。\
REQ-041-S05は今回のネイティブ202検査と物理入力、戦闘画像、通常復帰画像で開発側の確認を完了した。\
manual-checks.mdの利用者による最終確認は未確認のまま維持する。\
D-01の共通カタログ、D-02の保存境界と復元、D-03の最小入口と既存3列を維持し、実装の欠落や設計違反は見つからなかった。\
Libraryへの転送承認は成果物配送の障害として区別し、ゲーム仕様と実装の未検証とは扱わない。

strict差分とstrictトレースが成功した後、build-collectionのREQ-015を変更し、REQ-041を追加した。\
既存のPurposeと他要件が不変で、差分2ブロックが正式仕様へ完全一致することを比較した。\
全5仕様のstrict検証も成功し、2026-11-19-debug-unlocks-ten-step-lootへアーカイブした。\
CLIはproposalのWhyとWhat Changesという英語見出しがない旨の非停止警告を出したが、プロジェクトの日本語雛形に従った提案に目的と変更内容が存在し、仕様検証の問題ではない。

アーカイブ後のnpm run checkも成功した。\
証拠はartifacts/runtime/unlock-resume-check-archived.txtである。\
今回の開発側確認は完了し、利用者の最終確認と画像転送の承認が残る。
