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
生成されたOpenSpecスキルは手で編集しない。

## 参照する文書

- 目的と範囲: [product.md](openspec/product.md)
- 技術と検査の方針: [tech.md](openspec/tech.md)
- 構成と責務: [structure.md](openspec/structure.md)
- 開発の進め方: [AGENTS.md](AGENTS.md)
- 仕様書の一覧: [openspec/specs/README.md](openspec/specs/README.md)
