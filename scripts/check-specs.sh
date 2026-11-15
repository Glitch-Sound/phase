#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export XDG_CONFIG_HOME="$PWD/.tool-cache/config"
export XDG_DATA_HOME="$PWD/.tool-cache/data"
export OPENSPEC_TELEMETRY=0
export npm_config_cache="$PWD/.tool-cache/npm"
npx --no-install openspec validate --specs --strict
node scripts/openspec-trace.mjs check
node scripts/openspec-trace.mjs generate
