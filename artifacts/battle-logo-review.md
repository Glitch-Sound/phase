# 戦闘専用の小さく暗い横長ロゴ

## 変更

比較試案の幅300pxから210pxへ縮め、同じ676:184の比率でリングとPHASEを一体のまま表示する。\
戦闘のタイトル領域だけでRGBへ共通の0.55を掛け、透明度は1のまま、図柄と色相を維持して明るさを抑える。\
共通SVG、PNG、起動設定とBUILDのロゴは変更しない。\
位置と倍率はgame/tuning.gdの戦闘専用定義へ置く。

戦闘HUDへ入力を透過するTextureRectを置き、以前の文字と右の小さいマークを置換する。\
マップ、HP、タイムライン、PREVIEW、右の作戦とユニット情報、メニューと操作の位置や間隔を変えない。\
この変更は図案の寸法と明るさの視覚調整であり、OpenSpecのシナリオとゲームの規則は変えない。

## 検証

既存REQ-019-S03の文字集合の検査は、PHASEの文字描画1件を画像へ置き換える今回の依頼に合わせた。\
文字数と必須文字の他の期待を維持し、画像の同一性、元の縦横比、戦闘専用の寸法と色、入力透過の確認を加えた。\
変更前の実装で95確認中12件が失敗し、変更後に95件が成功した。\
検査コマンドとバランスに依存する期待値は追加していない。

- 前案と同じ6体と20パネルの配置を隔離fixtureへ再構成し、1歩の合法移動とWAITでTURN 02へ進めた
- Godotの実GPU描画で1920x1080と1152x648を確認した
- 同状態の現行版との画素差分はタイトル領域内の3814画素と1607画素だけで、外側は0画素だった
- 日英、標準と最小サイズのBUILDの4枚は以前の画像と全画素が一致した
- npm run checkとgit diff --checkが成功した
- Web Demoを別フォルダartifacts/runtime/web-battle-logoへ再生成した
- node tests/web_licenses.mjs artifacts/runtime/web-battle-logoとnode tests/web_session.mjsが成功した
- 全9権利文書、使用中5音、未使用2音の除外、デモの保存禁止、起動画像と小さいWebアイコンを維持した
- 実ブラウザの入口から初回通知、BUILD、戦闘、経路選択、行動選択、移動、TURN 02への更新を確認した
- WebのBUILDのSAVEとLOADは非活性であり、最後はRESTARTで通常のBUILDへ戻した

比較を優先する画像はartifacts/runtime/battle-logo-small/phase-battle-logo-small-ja-turn02-1920x1080.pngで、前の試案と同じ画角と配置のGodot実描画である。\
実Webの別の新規試合の画像はartifacts/runtime/battle-logo-small/phase-battle-logo-small-web-ja-turn02.pngで、1920x999のゲーム領域だけを取得した。\
JPEGの取得データを縮小や合成せずPNGへ保存した。\
両方とも個人情報とデスクトップは含まず、Library転送は親側へ委ねる。

Webでの英語と最小サイズの追加の手操作は未実施であり、日英と両サイズの表示はGodot側の確認と区別する。\
書き出し時に実エディター設定を保存する既存の試みはサンドボックスで拒否されたが、Web出力は成功した。\
実セーブと設定は保存せず、既存ファイルのハッシュで不変を確認する。

## 出力と公開候補

新版のWebはartifacts/runtime/web-battle-logo/index.htmlとし、以前のartifacts/runtime/webはd1f87caの旧出力として残す。\
最新版の公開候補はartifacts/runtime/public-source-small-logo-20261126/phaseへ独立して用意する。\
以前のpublic-source-battle-mark-20261126はd1f87ca、それ以前の2候補も旧版として保持し、上書きしない。\
元の履歴を改変せず、個人メールと端末固有パスを含まない1件の初回スナップショットという条件を維持する。\
外部公開とpushは行わない。
