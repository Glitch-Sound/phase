# BUILD配置の調整と検証

## 範囲

REQ-041-S01とREQ-044-S01の操作を維持する表示寸法と中央揃えの調整として直接変更した。
UNLOCK ALLとENEMY CPUを16の間隔で右へ揃え、UNIT 3との間隔を154にした。\
寸法は1920x1080の設計座標である。\
デバッグ入口がない場合はUNLOCK ALLのControl自体を作らず、ENEMY CPUの位置を変えない。

STARTは既存のアイコン幅20、文字とアイコンの間隔9を維持し、その合計幅から左右の余白を求める。\
通常、ホバー、押下、フォーカス、無効の各状態で同じ中央位置を使う。\
アイコンを中央へ重ねる指定は使わず、既存のButtonの入力とフォーカスを維持した。\
Godotの描画仕様は[公式Button資料](https://docs.godotengine.org/en/stable/classes/class_button.html)で確認した。

機能、戦闘式、編成、保存、設定と他画面は変更していない。\
検査コマンド、依存とOpenSpecのシナリオは変更していない。

## 検証

| 検査 | 結果 |
| --- | --- |
| 既存BUILD検査の強化 | 修正前27項目中6失敗、修正後27項目すべて成功。中央余白5状態とグループ間隔が修正前に失敗した |
| リリース相当の入口非表示 | ENEMY CPUのみ存在し、右端不変。既存実装でも成功した条件を維持した |
| npm run check | 成功。プロダクト検査、5仕様、トレース検査を含む |
| 実GPU描画 | 1152x648と1920x1080で18項目成功。デバッグ入口の有無、右端、STARTの明るい実画素の中心を確認した |
| 隔離した機能確認 | 各サイズで全解放開始、STARTによる6体戦闘、RESTART、全解放終了と通常BUILD復帰をGodotのコールバックで確認した |
| 実リリース書き出し | 5項目成功。デバッグビルド判定が偽、入口と直接呼出しの拒否、CPUのみの右寄せを確認した |
| git diff --check | 成功 |

各ログはartifacts/runtime/build-alignment-red.txt、build-alignment-green.txt、build-alignment-check.txt、build-alignment-gpu.txt、build-alignment-release-check.txtにある。\
実GPU画像はartifacts/runtime/build-alignment-debug-1152x648.png、build-alignment-debug-1920x1080.png、build-alignment-release-layout-1152x648.png、build-alignment-release-layout-1920x1080.pngにある。\
新コードの画像を読み取り、グループの余白、STARTの間隔、最小サイズの収まりを確認した。

## 保存境界と限界

検証は別の保存先と設定先を指定した。\
実セーブphase-save.jsonのSHA256は25167e282e85b12fd9f059ae72d9cb16e4d6fb55310b1d3f57295dd02a6573e2で、作業前と同じである。\
更新時刻も同じであり、ui-settings.jsonは未作成のままである。

既存のGodot埋め込み画面と新規実行画面の選択が安定せず、新コードに対するOSの物理クリックは確認しきれていない。\
実GPU描画とGodot内の機能呼出しによる確認とは区別する。\
実リリースの描画画像は作成せず、入口非表示の画面比較はデバッグ実行時に同じ非表示条件で確認した。\
戦闘の完走は今回の表示調整では再実施していない。\
全体検査が案内する既存の実機未確認18件を、今回確認したことにはしていない。\
通常BUILDを残して画面操作を終了し、画像アップロード、pushと公開は行っていない。
