"""REQ-005-S02、REQ-035-S05: 同じ合法な36条件を旧版と現行で比較する。"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "2017a4a1781c39451a0870adced066fc3155468f"
WORK = ROOT / "artifacts/runtime/tempo-study"
manifest = {}
for version in ("baseline", "current"):
    target = WORK / version
    target.mkdir(parents=True, exist_ok=True)
    manifest[version] = {}
    for source in sorted((ROOT / "game").glob("*.gd")):
        relative = source.relative_to(ROOT).as_posix()
        content = (subprocess.check_output(["git", "show", f"{BASELINE}:{relative}"], cwd=ROOT)
                   if version == "baseline" else source.read_bytes())
        manifest[version][relative] = hashlib.sha256(content).hexdigest()
        local = "res://" + target.relative_to(ROOT).as_posix() + "/"
        (target / source.name).write_text(content.decode().replace("res://game/", local))
    (target / "aggressive.gd").write_text(
        f'extends "res://{target.relative_to(ROOT).as_posix()}/cpu_policy.gd"\n'
        'func _danger(after,actor:int,threats:Array)->float:\n'
        '\treturn super._danger(after,actor,threats)*0.4\n')
log_path = WORK / "run.log"
with log_path.open("w") as log:
    completed = subprocess.run(["godot", "--headless", "--path", str(ROOT), "--script",
                                "tests/tempo_study.gd"], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
log_text = log_path.read_text()
if completed.returncode or any(x in log_text for x in ("SCRIPT ERROR", "FAIL:", "Assertion failed")):
    raise SystemExit(log_text)
rows = json.loads((WORK / "results.json").read_text())
report = {"baseline_commit": BASELINE, "hands": "両陣営の1ユニットの移動と行動を1手とする。移動終局とWAITも1手である。",
          "limit": 160, "source_sha256": manifest, "summaries": {}, "runs": []}
for version in ("baseline", "current"):
    subset = [x for x in rows if x["version"] == version]
    hands = sorted(x["hands"] for x in subset)
    assert len(subset) == 36
    report["summaries"][version] = {
        "count": len(subset), "mean": sum(hands)/len(hands), "median": (hands[17]+hands[18])/2,
        "min": hands[0], "max": hands[-1], "hands": hands,
        "victories": sum(x["result"] == "VICTORY" for x in subset),
        "defeats": sum(x["result"] == "DEFEAT" for x in subset),
        "unfinished": sum(not x["result"] for x in subset),
        "heals": sum(x["heals"] for x in subset), "full_hp_kills": sum(x["full_hp_kills"] for x in subset),
        "max_hit": max(x["max_hit"] for x in subset), "max_repetition": max(x["max_repetition"] for x in subset),
        "stages": {str(stage): [x["hands"] for x in subset if x["stage"] == stage] for stage in range(4)}}
    for row in subset:
        report["runs"].append({key: value for key, value in row.items() if key != "history"})
assert [(x["kind"], x["stage"], x["seed"]) for x in rows[:36]] == [(x["kind"], x["stage"], x["seed"]) for x in rows[36:]]
destination = ROOT / "artifacts/turn-tempo-comparison.json"
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report["summaries"], ensure_ascii=False, indent=2))
print(destination)
