#!/bin/zsh
# Headless performance benchmark (stress config: all camps active, lazy
# activation off, `multiplier` mobs per camp slot). Runs sequentially so the
# runs do not compete for CPU; reports the median of each metric plus the
# process CPU time (more robust than wall time on a busy machine) and the
# mean number of entities per TickScheduler LOD bucket.
#
#   tools/bench.sh [runs=5] [multiplier=2] [frames=1800] [warmup=600] [onscreen=0] [rigs_awake=0] [speed=0]
#   OUT=/path/bench.jsonl tools/bench.sh ...      # also keep the raw lines (every monster's)
#   MONSTER=<id> tools/bench.sh ...               # one roster monster (default: the roster default)
#   MONSTER=all tools/bench.sh ...                # every roster monster in turn, one summary each
#
# Run r plays seed r. Runs vary from one invocation to the next: the bench
# keeps the navigation server's asynchronous map and region iterations on (the
# device's setting and part of the cost measured), so the match drifts with
# CPU load, and a seed whose heroes meet the monster early can end the match
# inside the window (seed 3 with every rig awake, sometimes). Such a run stops
# at the match end (the tree pauses there) and is flagged below its summary;
# one that ended in the warm-up measured nothing and is left out of the
# medians. Use 5 or more runs for a performance gate, and run the before and
# after benches back to back on the same machine state.
#
# Headless, nothing is drawn, so no mob is ever on screen: only the heroes and
# the monster tick every frame (FULL) and every mob ticks at 20/10/3 Hz.
# onscreen=1 marks the mobs inside the camera rect on screen each frame, as
# the VisibleOnScreenNotifier2D does on a device, so they tick at FULL rate
# (and their CharacterRigs animate). rigs_awake=1 wakes EVERY CharacterRig
# (the zoomed-out worst case); rigs_awake_mean reports how many animated.
#
# speed is the match speed a player watches at (README "Match Speed"): 0 keeps
# game time (every frame is 1/60 game second, as in the sims; the default and
# the number to compare between commits), 1 plays the match's base speed and 2
# the speed button's fast setting. The summary prints the time scale: a frame
# then covers that many sixtieths of a game second, which is what a 60 fps
# device has to fit into one frame at that speed.
#
# Works on a temp copy with its own user:// (override.cfg), never on the real
# project directory. An unknown MONSTER id fails (exit 2).
setopt NULL_GLOB
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUNS="${1:-5}"; MULT="${2:-2}"; FRAMES="${3:-1800}"; WARMUP="${4:-600}"; ONSCREEN="${5:-0}"; RIGS="${6:-0}"; SPEED="${7:-0}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/monster_env.zsh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/evolvemobile_bench_$$"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_bench_%d"\n' "$$" > "$TMP/proj/override.cfg"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1
resolve_monsters "$TMP/proj" || exit 2
STATUS=0
first=1
for m in "${MONSTERS[@]}"; do
  res="$TMP/results_${m:-default}.jsonl"
  : > "$res"
  for ((r = 1; r <= RUNS; r++)); do
    /usr/bin/time -p "$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/proj" \
      -s res://tools/bench_match.gd -- "$r" "$WARMUP" "$FRAMES" "$MULT" "$ONSCREEN" "$RIGS" "$SPEED" ${m:+monster=$m} > "$TMP/run_$r.log" 2> "$TMP/time_$r.log"
    line="$(grep "^BENCH_RESULT " "$TMP/run_$r.log" | sed 's/^BENCH_RESULT //')"
    if [ -z "$line" ]; then echo "${m:+$m }run $r produced no result:"; grep -E "SCRIPT ERROR|ERROR" "$TMP/run_$r.log" | head -5; continue; fi
    cpu="$(awk '/^user/ {u=$2} /^sys/ {s=$2} END {print u + s}' "$TMP/time_$r.log")"
    echo "$line" | python3 -c "import json,sys; d=json.load(sys.stdin); d['cpu_s']=float(sys.argv[1]); print(json.dumps(d))" "$cpu" >> "$res"
  done
  cat "$res" >> "$TMP/results.jsonl"
  (( first )) || echo
  first=0
  python3 - "$res" "$FRAMES" <<'PY' || STATUS=1
import json, statistics, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
window = int(sys.argv[2])
if not rows:
    print("no results"); sys.exit(1)
measured = [r for r in rows if r["frames"] > 0]
print(f"runs: {len(measured)}/{len(rows)}  monster: {rows[0].get('monster', 'grount')}  frames/run: {window}"
      f"  multiplier: {rows[0]['multiplier']}  onscreen: {rows[0].get('onscreen', 0)}  rigs_awake: {rows[0].get('rigs_awake', 0)}"
      f"  time_scale: {rows[0].get('time_scale', 1.0)}")
for k in ("frame_ms_mean", "frame_ms_p50", "frame_ms_p95", "frame_ms_p99", "frame_ms_max",
          "process_peak_ms", "physics_peak_ms", "cpu_s", "peak_mobs", "peak_nodes", "peak_collision_pairs",
          "rigs_awake_mean"):
    vals = [r[k] for r in measured if k in r]
    if not vals:
        continue
    print(f"  {k:22s} median {statistics.median(vals):10.3f}   (min {min(vals):.3f}, max {max(vals):.3f})")
for b in ("FULL", "NEAR", "MID", "FAR"):
    vals = [r["lod_counts"][b] for r in measured if b in r.get("lod_counts", {})]
    if vals:
        print(f"  {'lod_' + b:22s} median {statistics.median(vals):10.3f}   (min {min(vals):.3f}, max {max(vals):.3f})")
for r in rows:
    if r.get("ended_at_frame", -1) >= 0:
        print(f"  ended early: seed {r['seed']} at frame {r['ended_at_frame']}, measured {r['frames']} of {window} frames"
              + ("" if r["frames"] else " (left out)"))
if not measured:
    sys.exit(1)
PY
done
[ -n "$OUT" ] && cp "$TMP/results.jsonl" "$OUT"
exit $STATUS
