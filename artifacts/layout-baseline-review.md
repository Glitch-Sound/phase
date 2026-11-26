# CLASSとMUTATIONの文字の縦位置

## 参照と範囲

利用者のLibrary参照libfile_7cc8ad1c2bbc8191b4f76769f99b56b5を、現在のLibrary手順のprepare_materializeと公式転送ヘルパーでMacへ取得した。\
実ファイルの読取、PNG署名、24085バイト、685x180を確認し、実ピクセルでCLASSとSTANDARDよりVIRSLが下へずれていることを確認した。\
再試行は不要だった。

参照の実パスはartifacts/runtime/class-baseline-reference-20261119/0CC7DC0B-D6E4-4504-A09B-6785AFEAF410.pngである。\
ゲーム素材として参照していない。

REQ-045-S04に関係する表示位置の直接調整として扱い、仕様のシナリオと文言、選択、解放、保存は変更していない。\
対象はBUILDのCLASSとARMS、GEARそれぞれのMUTATIONの3行である。

## 変更

中央揃えの主コードの文字寸法から基準線を求め、タイトルとSTANDARDのフォントの上昇量を使って同じ基準線へ置く共通処理を使った。\
通常時の入力欄の上下余白は、既存のホバー時と同じ対称な余白へ揃えた。\
STANDARDの有無で主コードの位置を変えず、各入力欄の位置、寸法とクリック領域を維持した。\
フォント、文字サイズ、配色と他の画面は変更していない。

## 検証

| 検査 | 結果 |
| --- | --- |
| BUILDの既存検査拡張 | 修正前39項目中3失敗、修正後39項目成功。3行の基準線とSTANDARDなしの主コード位置を確認した |
| npm run check | 成功。全プロダクト検査、5仕様とトレースを含む |
| 実GPUの操作と画面 | 1152x648と1920x1080、30項目成功。選択、取消、確定、全解放、START、RESETと通常復帰を維持した |
| 実GPUの表示状態 | 同じ2サイズ、10項目成功。3行すべてでSTANDARDありとなし、ホバーを撮影し、クリック領域不変と有効な構成を確認した |
| 原寸の文字画素 | 変更前後6項目と表示状態24項目が成功。下記の見える文字下端を比較した |
| git diff --check | 成功 |

標準サイズではタイトル、主コードとSTANDARDの見える下端の差が、CLASSで5pxから0px、両MUTATIONで4pxから1pxへ減った。\
最小サイズも0から1pxに収まり、STANDARDの有無とホバーによる主コードの下端の変化は、観測した全3行で0pxだった。\
残る1pxは文字サイズとラスター化の違いによるもので、論理座標の基準線は一致している。\
画像を実際に開いて、文字位置、下線との余白、クリッピングがないことを確認した。

ログはartifacts/runtime/layout-baseline-red.txt、layout-baseline-green.txt、layout-baseline-check.txt、layout-baseline-gpu.txt、layout-field-states-gpu.txt、layout-baseline-pixels.txt、layout-baseline-state-pixels.txtにある。\
検査コマンドとテストファイルは追加せず、既存の共通ダイアログ検査に4項目を加えた。

確認画像は次にある。

- artifacts/runtime/layout-baseline-build-1920x1080.png
- artifacts/runtime/layout-baseline-fields-standard-1152x648.png
- artifacts/runtime/layout-baseline-fields-nonstandard-1920x1080.png
- artifacts/runtime/layout-baseline-fields-standard-hover-1920x1080.png

## 境界と未確認

GPU画面とGodotのGUI入力イベントによる検証であり、OSの物理マウスの操作と自然な手動対戦は再実施していない。\
最小と標準以外のサイズを今回新たに確認したとは扱わない。\
既存の実機確認19件の状態は変えていない。\
検証用Godotは通常BUILDへ戻してから終了した。

実セーブphase-save.jsonのSHA256は25167e282e85b12fd9f059ae72d9cb16e4d6fb55310b1d3f57295dd02a6573e2、更新時刻は1794705159636683302であり、作業前と一致した。\
ui-settings.jsonは未作成のままである。\
画像アップロード、pushと公開は行っていない。
