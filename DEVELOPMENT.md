# 開発

OpenSpecを使ってPHASEを開発する人のための文書である。\
利用者向けの説明は[README.md](README.md)に置く。\
OpenSpecの部分を切り離して納品する場合、このファイルは.gitattributesの指定で納品物から除かれる。

## OpenSpecの設定

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

プロダクト検査はscripts/check.sh、仕様とトレースの検査はscripts/check-specs.shが担当する。\
コミット前のフックがnpm run checkを実行する。\
生成されたOpenSpecスキルは手で編集しない。\
GitHubへのpushとゲームの公開は行っていない。

## 自作ソースの静的解析と整形

Godotの構文と型の検査、APIコメントの検査と回帰確認はnpm run checkで実行する。\
GDScriptの補助的な静的解析と整形には、プロジェクト内へ隔離したgdtoolkit 4.5.0を使える。\
ゲームの実行時依存とシステム全体のPython環境には追加しない。

~~~sh
python3 -m venv .tool-cache/source-review-venv
.tool-cache/source-review-venv/bin/python -m pip install gdtoolkit==4.5.0
.tool-cache/source-review-venv/bin/gdlint game ui tests
.tool-cache/source-review-venv/bin/gdformat --check game ui tests
~~~

既存の短縮記法には汎用スタイルとの相違があり、補助診断の失敗と既定検査の成否を区別して報告する。\
全面整形やルールの無効化で差分を増やさず、編集する部品や関数に絞って整形する。\
既存のテストや検査は弱めない。

生成されたOpenSpecスキルのMIT表記に対応する原文はdocs/licenses/OpenSpec-LICENSE.txtへ保持する。\
固定した@fission-ai/openspec 1.16.0の配布パッケージに含まれるLICENSEを変更せず記録したものであり、PHASEの自作コードへライセンスを設定するものではない。\
node_modulesと隔離したgdtoolkitはリポジトリやゲームの配布対象にしない。

## 参照する文書

- 目的と範囲: [product.md](openspec/product.md)
- 技術と検査の方針: [tech.md](openspec/tech.md)
- 構成と責務: [structure.md](openspec/structure.md)
- 開発の進め方: [AGENTS.md](AGENTS.md)
- 仕様書の一覧: [openspec/specs/README.md](openspec/specs/README.md)
