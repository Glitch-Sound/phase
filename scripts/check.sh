#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p artifacts/runtime
node scripts/lint.mjs
# SVGインポートを含め、初回の検査でも同じアセットを利用する。
godot --headless --editor --import --path . --quit --log-file "$PWD/artifacts/runtime/import.log" > artifacts/runtime/import-output.txt 2>&1
if rg 'SCRIPT ERROR|Failed to load script' artifacts/runtime/import-output.txt; then
  exit 1
fi
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

for suite in review_regressions contested_play display_flow design_flow restored_interface map_chrome unit_glyphs arc_strokes ring_palette phase_preview battle_labels time_axis side_information route_clearance panel_generation panel_interface panel_play; do
  godot --headless --path . --script "tests/$suite.gd" --log-file "$PWD/artifacts/runtime/$suite.log" > "artifacts/runtime/$suite-output.txt" 2>&1
  cat "artifacts/runtime/$suite-output.txt"
  if rg 'SCRIPT ERROR|FAIL:|Failed to load script' "artifacts/runtime/$suite-output.txt"; then
    exit 1
  fi
done
rg 'REVIEW REGRESSIONS: [0-9]+ checks / 0 failures' artifacts/runtime/review_regressions-output.txt
rg 'CONTESTED PLAY: PASS' artifacts/runtime/contested_play-output.txt
rg 'DISPLAY FLOW: [0-9]+ checks / 0 failures' artifacts/runtime/display_flow-output.txt

rg 'DESIGN FLOW: [0-9]+ checks / 0 failures' artifacts/runtime/design_flow-output.txt
rg 'RESTORED INTERFACE: [0-9]+ checks / 0 failures' artifacts/runtime/restored_interface-output.txt
rg 'MAP CHROME: [0-9]+ checks / 0 failures' artifacts/runtime/map_chrome-output.txt
rg 'UNIT GLYPHS: [0-9]+ checks / 0 failures' artifacts/runtime/unit_glyphs-output.txt
rg 'ARC STROKES: [0-9]+ checks / 0 failures' artifacts/runtime/arc_strokes-output.txt
rg 'RING PALETTE: [0-9]+ checks / 0 failures' artifacts/runtime/ring_palette-output.txt
rg 'PHASE PREVIEW: [0-9]+ checks / 0 failures' artifacts/runtime/phase_preview-output.txt
rg 'BATTLE LABELS: [0-9]+ checks / 0 failures' artifacts/runtime/battle_labels-output.txt
rg 'TIME AXIS: [0-9]+ checks / 0 failures' artifacts/runtime/time_axis-output.txt

rg 'SIDE INFORMATION: [0-9]+ checks / 0 failures' artifacts/runtime/side_information-output.txt

rg 'ROUTE CLEARANCE: [0-9]+ checks / 0 failures' artifacts/runtime/route_clearance-output.txt

rg 'PANEL GENERATION: [0-9]+ checks / 0 failures' artifacts/runtime/panel_generation-output.txt
rg 'PANEL INTERFACE: [0-9]+ checks / 0 failures' artifacts/runtime/panel_interface-output.txt
rg 'GENERATED MAP PLAY: PASS' artifacts/runtime/panel_play-output.txt

# macOS sandboxの証明書初期化警告を除き、エンジンの描画エラー等も失敗にする。
for log in test-output smoke-output replay-output ui-output review_regressions-output contested_play-output display_flow-output design_flow-output restored_interface-output map_chrome-output unit_glyphs-output arc_strokes-output ring_palette-output phase_preview-output battle_labels-output time_axis-output side_information-output route_clearance-output panel_generation-output panel_interface-output panel_play-output; do
  if rg '^ERROR:' "artifacts/runtime/$log.txt" | rg -v '^ERROR: Condition "ret != noErr" is true. Returning: ""$'; then
    exit 1
  fi
done
