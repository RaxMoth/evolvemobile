#!/bin/zsh
# Headless performance benchmark (stress config: all camps active, lazy
# activation off, `multiplier` mobs per camp slot). Runs sequentially so the
# runs do not compete for CPU; reports the median of each metric plus the
# process CPU time (more robust than wall time on a busy machine) and the
# mean number of entities per TickScheduler LOD bucket.
#
#   tools/bench.sh [runs=3] [multiplier=2] [frames=1800] [warmup=600] [onscreen=0] [rigs_awake=0]
#   OUT=/path/bench.jsonl tools/bench.sh ...      # also keep the raw lines
#
# Headless, nothing is drawn, so no mob is ever on screen: only the heroes and
# the monster tick every frame (FULL) and every mob ticks at 20/10/3 Hz.
# onscreen=1 marks the mobs inside the camera rect on screen each frame, as
# the VisibleOnScreenNotifier2D does on a device, so they tick at FULL rate
# (and their CharacterRigs animate). rigs_awake=1 wakes EVERY CharacterRig
# (the zoomed-out worst case); rigs_awake_mean reports how many animated.
#
# Works on a temp copy with its own user:// (override.cfg), never on the real
# project directory.
setopt NULL_GLOB
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUNS="${1:-3}"; MULT="${2:-2}"; FRAMES="${3:-1800}"; WARMUP="${4:-600}"; ONSCREEN="${5:-0}"; RIGS="${6:-0}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/evolvemobile_bench_$$"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_bench_%d"\n' "$$" > "$TMP/proj/override.cfg"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1
for ((r = 1; r <= RUNS; r++)); do
  /usr/bin/time -p "$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/proj" \
    -s res://tools/bench_match.gd -- "$r" "$WARMUP" "$FRAMES" "$MULT" "$ONSCREEN" "$RIGS" > "$TMP/run_$r.log" 2> "$TMP/time_$r.log"
  line="$(grep "^BENCH_RESULT " "$TMP/run_$r.log" | sed 's/^BENCH_RESULT //')"
  if [ -z "$line" ]; then echo "run $r produced no result:"; grep -E "SCRIPT ERROR|ERROR" "$TMP/run_$r.log" | head -5; continue; fi
  cpu="$(awk '/^user/ {u=$2} /^sys/ {s=$2} END {print u + s}' "$TMP/time_$r.log")"
  echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); d['cpu_s']=float(sys.argv[1]); print(json.dumps(d))" "$cpu" >> "$TMP/results.jsonl"
done
[ -n "$OUT" ] && cp "$TMP/results.jsonl" "$OUT"
python3 - "$TMP/results.jsonl" <<'PY'
import json, statistics, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
if not rows:
    print("no results"); sys.exit(1)
print(f"runs: {len(rows)}  frames/run: {rows[0]['frames']}  multiplier: {rows[0]['multiplier']}"
      f"  onscreen: {rows[0].get('onscreen', 0)}  rigs_awake: {rows[0].get('rigs_awake', 0)}")
for k in ("frame_ms_mean", "frame_ms_p50", "frame_ms_p95", "frame_ms_p99", "frame_ms_max",
          "process_peak_ms", "physics_peak_ms", "cpu_s", "peak_mobs", "peak_nodes", "peak_collision_pairs",
          "rigs_awake_mean"):
    vals = [r[k] for r in rows if k in r]
    if not vals:
        continue
    print(f"  {k:22s} median {statistics.median(vals):10.3f}   (min {min(vals):.3f}, max {max(vals):.3f})")
for b in ("FULL", "NEAR", "MID", "FAR"):
    vals = [r["lod_counts"][b] for r in rows if b in r.get("lod_counts", {})]
    if vals:
        print(f"  {'lod_' + b:22s} median {statistics.median(vals):10.3f}   (min {min(vals):.3f}, max {max(vals):.3f})")
PY
