#!/bin/zsh
# Headless performance benchmark (stress config: all camps active, lazy
# activation off, `multiplier` mobs per camp slot). Runs sequentially so the
# runs do not compete for CPU; reports the median of each metric plus the
# process CPU time (more robust than wall time on a busy machine).
#
#   tools/bench.sh [runs=3] [multiplier=2] [frames=1800] [warmup=600]
#   OUT=/path/bench.jsonl tools/bench.sh ...      # also keep the raw lines
#
# Works on a temp copy with its own user:// (override.cfg), never on the real
# project directory.
setopt NULL_GLOB
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUNS="${1:-3}"; MULT="${2:-2}"; FRAMES="${3:-1800}"; WARMUP="${4:-600}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/evolvemobile_bench_$$"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_bench_%d"\n' "$$" > "$TMP/proj/override.cfg"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1
for ((r = 1; r <= RUNS; r++)); do
  /usr/bin/time -p "$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/proj" \
    -s res://tools/bench_match.gd -- "$r" "$WARMUP" "$FRAMES" "$MULT" > "$TMP/run_$r.log" 2> "$TMP/time_$r.log"
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
print(f"runs: {len(rows)}  frames/run: {rows[0]['frames']}  multiplier: {rows[0]['multiplier']}")
for k in ("frame_ms_mean", "frame_ms_p50", "frame_ms_p95", "frame_ms_p99", "frame_ms_max",
          "process_peak_ms", "physics_peak_ms", "cpu_s", "peak_mobs", "peak_nodes", "peak_collision_pairs"):
    vals = [r[k] for r in rows if k in r]
    if not vals:
        continue
    print(f"  {k:22s} median {statistics.median(vals):10.3f}   (min {min(vals):.3f}, max {max(vals):.3f})")
PY
