#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p artifacts/runtime
node scripts/lint.mjs
godot --headless --path . --script tests/run.gd --log-file "$PWD/artifacts/runtime/tests.log" > artifacts/runtime/test-output.txt 2>&1
cat artifacts/runtime/test-output.txt
if rg 'SCRIPT ERROR|FAIL:|Failed to load script' artifacts/runtime/test-output.txt; then
  exit 1
fi
rg 'PHASE TESTS: [0-9]+ checks / 0 failures' artifacts/runtime/test-output.txt
godot --headless --path . --quit-after 3 --log-file "$PWD/artifacts/runtime/smoke.log" > artifacts/runtime/smoke-output.txt 2>&1
if rg 'SCRIPT ERROR|Failed to load script' artifacts/runtime/smoke-output.txt; then
  exit 1
fi

godot --headless --path . --script tests/playthrough.gd --log-file "$PWD/artifacts/runtime/playthrough.log" > artifacts/runtime/replay-output.txt 2>&1
cat artifacts/runtime/replay-output.txt
if rg "SCRIPT ERROR|FAIL:|Failed to load script" artifacts/runtime/replay-output.txt; then
  exit 1
fi
rg "FULL BATTLE REPLAY:.*PASS" artifacts/runtime/replay-output.txt

godot --headless --path . --script tests/ui_flow.gd --log-file "$PWD/artifacts/runtime/ui-flow.log" > artifacts/runtime/ui-output.txt 2>&1
cat artifacts/runtime/ui-output.txt
if rg 'SCRIPT ERROR|FAIL:|Failed to load script' artifacts/runtime/ui-output.txt; then
  exit 1
fi
rg 'UI CONNECTIONS: [0-9]+ checks / 0 failures' artifacts/runtime/ui-output.txt
