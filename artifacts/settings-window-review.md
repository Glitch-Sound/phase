# 設定とBUILDの確認

## 変更

言語の補足、RINGSの補足と通常成功文を日英で削除し、失敗の表示は残した。SETTINGSは操作領域を88px短くし、BUILDはヘッダー下だけ12px空け、下部ボタンを維持した。

## 表示切替

修正前の単独macOS起動でもWINDOWEDとFULLSCREENの実モードは一致した。ユーザーの実画面はGodotエディター埋め込みであり、Engine.is_embedded_in_editorの公式仕様はそこでのウィンドウモード変更が非対応であると説明している。埋め込みでは切替を説明付きで無効にし、未適用の選択表示を作らない。単独実行では所属Windowへ要求し、ネイティブ状態が安定後だけ.display.jsonへ明示選択を保存する。起動の復元とDEBUG中の一時選択は書き込まず、非同期の旧状態で既存値を上書きしない。

## 検証

- 修正前のdesign_flowは説明削除と表示部品の2件で失敗し、実装後は埋め込みを含む検査が成功した。
- npm run check成功。既存の説明必須の期待値は今回の明示的削除に合わせて変更した。
- Apple M4、Godot4.7.2、Compatibilityの実ウィンドウで40件成功。  クリックでFULLSCREEN、WINDOWED、FULLSCREEN、再表示と配色保存、復元、英日1920x1080と1152x648、SLOT2、3、1、収まりを確認した。
- 新規プロセスでもFULLSCREEN復元と設定の非上書きを確認した。
- キャプチャの実ピクセルを見て、指定説明の不在とBUILD下部の余白を確認した。

## 限界

macOSのOS操作によるフルスクリーン退出と、エディター内での最終ビルドのクリックは未確認である。埋め込みの非活性はfixtureで確認し、実行形式の判定は公式APIを使う。実機確認台帳の既存未確認をこの補助確認だけで完了にしない。通常のセーブと設定は使用していない。

## ローカル画像

- artifacts/runtime/settings-window/phase-settings-compact-ja-1920x1080.png
- artifacts/runtime/settings-window/phase-build-header-ja-1920x1080.png
- 同じ場所に1152x648も保持した。
