#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# 既存の英語文言の検査はOSの優先言語に依存させない。
godot() { command godot --language en "$@"; }
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

for suite in assembly_identity assembly_identity_ui unit_identity unit_identity_ui convergence turn_plan movement movement_ui review_regressions contested_play display_flow design_flow restored_interface map_chrome unit_glyphs arc_strokes ring_palette phase_preview battle_labels time_axis side_information route_clearance panel_generation panel_interface core_panels core_panel_ui panel_play interface_hierarchy cpu_policy cpu_turn cpu_interface cpu_play decision_model decision_interface turn_follow tempo_risk skill_patterns skill_pattern_cpu skill_pattern_ui utility_skills utility_cpu utility_ui rotation_fields rotation_field_ui debug_unlock debug_unlock_ui build_choices build_dialogs three_unit_squads english_ui language sfx; do
  godot --headless --path . --script "tests/$suite.gd" --log-file "$PWD/artifacts/runtime/$suite.log" > "artifacts/runtime/$suite-output.txt" 2>&1
  cat "artifacts/runtime/$suite-output.txt"
  if rg 'SCRIPT ERROR|FAIL:|Failed to load script' "artifacts/runtime/$suite-output.txt"; then
    exit 1
  fi
done
rg 'CONVERGENCE: [0-9]+ checks / 0 failures' artifacts/runtime/convergence-output.txt
rg 'TURN PLAN: [0-9]+ checks / 0 failures' artifacts/runtime/turn_plan-output.txt
rg 'ASSEMBLY IDENTITY: [0-9]+ checks / 0 failures' artifacts/runtime/assembly_identity-output.txt
rg 'ASSEMBLY IDENTITY UI: [0-9]+ checks / 0 failures' artifacts/runtime/assembly_identity_ui-output.txt
rg 'UNIT IDENTITY: [0-9]+ checks / 0 failures' artifacts/runtime/unit_identity-output.txt
rg 'UNIT IDENTITY UI: [0-9]+ checks / 0 failures' artifacts/runtime/unit_identity_ui-output.txt
rg 'MOVEMENT: [0-9]+ checks / 0 failures' artifacts/runtime/movement-output.txt
rg 'MOVEMENT UI: [0-9]+ checks / 0 failures' artifacts/runtime/movement_ui-output.txt
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
rg 'CORE PANELS: [0-9]+ checks / 0 failures' artifacts/runtime/core_panels-output.txt
rg 'CORE PANEL UI: [0-9]+ checks / 0 failures' artifacts/runtime/core_panel_ui-output.txt
rg 'GENERATED MAP PLAY: PASS' artifacts/runtime/panel_play-output.txt

rg 'INTERFACE HIERARCHY: [0-9]+ checks / 0 failures' artifacts/runtime/interface_hierarchy-output.txt

rg 'CPU POLICY: [0-9]+ checks / 0 failures' artifacts/runtime/cpu_policy-output.txt
rg 'CPU TURN: [0-9]+ checks / 0 failures' artifacts/runtime/cpu_turn-output.txt
rg 'CPU INTERFACE: [0-9]+ checks / 0 failures' artifacts/runtime/cpu_interface-output.txt
rg 'CPU PLAY: [0-9]+ checks / 0 failures' artifacts/runtime/cpu_play-output.txt
rg 'TACTICAL DECISIONS MODEL: [0-9]+ checks / 0 failures' artifacts/runtime/decision_model-output.txt
rg 'TACTICAL DECISIONS UI: [0-9]+ checks / 0 failures' artifacts/runtime/decision_interface-output.txt
rg 'TURN FOLLOW: [0-9]+ checks / 0 failures' artifacts/runtime/turn_follow-output.txt
rg 'TEMPO RISK: [0-9]+ checks / 0 failures' artifacts/runtime/tempo_risk-output.txt

rg 'SKILL PATTERNS: [0-9]+ checks / 0 failures' artifacts/runtime/skill_patterns-output.txt
rg 'SKILL PATTERN CPU: [0-9]+ checks / 0 failures' artifacts/runtime/skill_pattern_cpu-output.txt
rg 'SKILL PATTERN UI: [0-9]+ checks / 0 failures' artifacts/runtime/skill_pattern_ui-output.txt

rg 'UTILITY SKILLS: [0-9]+ checks / 0 failures' artifacts/runtime/utility_skills-output.txt
rg 'UTILITY CPU: [0-9]+ checks / 0 failures' artifacts/runtime/utility_cpu-output.txt
rg 'UTILITY UI: [0-9]+ checks / 0 failures' artifacts/runtime/utility_ui-output.txt
rg 'ROTATION FIELDS: [0-9]+ checks / 0 failures' artifacts/runtime/rotation_fields-output.txt
rg 'ROTATION FIELD UI: [0-9]+ checks / 0 failures' artifacts/runtime/rotation_field_ui-output.txt
rg 'DEBUG UNLOCK: [0-9]+ checks / 0 failures' artifacts/runtime/debug_unlock-output.txt
rg 'DEBUG UNLOCK UI: [0-9]+ checks / 0 failures' artifacts/runtime/debug_unlock_ui-output.txt

rg 'BUILD CHOICES: [0-9]+ checks / 0 failures' artifacts/runtime/build_choices-output.txt
rg 'BUILD DIALOGS: [0-9]+ checks / 0 failures' artifacts/runtime/build_dialogs-output.txt
rg 'THREE UNIT SQUADS: [0-9]+ checks / 0 failures' artifacts/runtime/three_unit_squads-output.txt
rg 'ENGLISH UI: [0-9]+ checks / 0 failures' artifacts/runtime/english_ui-output.txt
rg 'SFX: [0-9]+ checks / 0 failures' artifacts/runtime/sfx-output.txt

# macOS sandboxの証明書初期化警告を除き、エンジンの描画エラー等も失敗にする。
for log in assembly_identity-output assembly_identity_ui-output unit_identity-output unit_identity_ui-output convergence-output turn_plan-output movement-output movement_ui-output test-output smoke-output replay-output ui-output review_regressions-output contested_play-output display_flow-output design_flow-output restored_interface-output map_chrome-output unit_glyphs-output arc_strokes-output ring_palette-output phase_preview-output battle_labels-output time_axis-output side_information-output route_clearance-output panel_generation-output panel_interface-output core_panels-output core_panel_ui-output panel_play-output interface_hierarchy-output cpu_policy-output cpu_turn-output cpu_interface-output cpu_play-output decision_model-output decision_interface-output turn_follow-output tempo_risk-output skill_patterns-output skill_pattern_cpu-output skill_pattern_ui-output utility_skills-output utility_cpu-output utility_ui-output rotation_fields-output rotation_field_ui-output debug_unlock-output debug_unlock_ui-output build_choices-output build_dialogs-output three_unit_squads-output english_ui-output sfx-output; do
  if rg '^ERROR:' "artifacts/runtime/$log.txt" | rg -v '^ERROR: Condition "ret != noErr" is true. Returning: ""$'; then
    exit 1
  fi
done
