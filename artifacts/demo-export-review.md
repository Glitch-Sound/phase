# デモ用書き出しの検証

## 変更と前提

Web Demoプリセットのdemoタグで保存の非活性を制御する。
エディター通常起動とdemoタグなしの製品は既存のファイル保存を維持する。
Webとデモの設定は共通メモリ境界へ接続し、SAVEとLOADの内部入口もデモでは拒否する。
UNLOCK ALLとは別の条件とし、デバッグの隔離を維持する。

## 検査

- 新しいデモ検査とプリセット検査が変更前に失敗した。
- starter_profileは39件成功し、通常の新規と既存、再起動、Web設定と新規セッション、デモの保存拒否と構成保持を検査した。
- 保存拒否は有効な別の保存候補をメモリへ用意して確認し、保存と読込の両方が同じ正確な拒否結果となり、元の編成と保存候補を変えないことを確認した。
- Webシェルの永続化禁止とdemoタグの検査が成功した。
- npm run checkが成功した。プロダクト検査コマンドの構成は変更していない。
- Web DemoからPCKを書き出せた。実PCKをGodot 4.7.2のmacOSランタイムで読み、OS.has_feature("demo")がtrueで保存先がメモリになることを確認した。
- 実PCKのウィンドウで英日、1920x1080と1152x648の20件が成功した。両ボタンの非活性、クリックによる非実行、内部入口の拒否、戦闘からBUILDへの構成と解放の保持を確認した。
- 通常速度の実画面を撮り、日本語BUILDの非活性SAVEとLOADを目視確認した。UI入力はGodotへ入力イベントを渡したものであり、OSの物理マウス操作とは区別する。

## 成果物

- artifacts/runtime/demo-export/phase-demo-build-ja-1920x1080.png
- artifacts/runtime/demo-export/phase-demo-build-ja-1152x648.png
- artifacts/runtime/demo-export/runtime-result.json
- artifacts/runtime/demo-export/demo.pck
- artifacts/runtime/demo-export/export.txt
- artifacts/runtime/demo-export/check.txt

画像とPCKはローカルの検証物であり、Libraryや外部ホストへ送信していない。

## 未検証と制約

HTML一式の書き出しを実行したが、同じ版のweb_nothreads_debug.zipとweb_nothreads_release.zipが未導入のため失敗した。
macOSのエディター設定保存もサンドボックスから拒否され、実設定は変更していない。
実ブラウザの起動、再読み込み、日本語フォントと音、itch.ioとunityroom上の動作は未検証である。
メモリとプロフィールの再初期化で、識別可能な名前と設定が初期化され、同セッションでは保持されることを代替確認した。
ホストのHTMLを使うunityroomではカスタムシェルは適用されないが、実PCKのdemoタグによるゲームと設定のメモリ限定処理は確認した。
利用者の最終実機確認はmanual-checks.mdの未確認を維持する。

## 判定

検査できた範囲で仕様と実装の相違は見つからない。
Webテンプレート導入後の実ブラウザと配布先の統合動作は、確認できたものとして扱わない。
