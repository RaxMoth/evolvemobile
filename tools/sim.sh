#!/bin/zsh
# Headless balance simulation: N seeded auto-play matches in parallel.
#
#   tools/sim.sh [runs=24] [side=heroes|monster] [workers=6] [cap_seconds=660]
#   OUT=/path/results.jsonl tools/sim.sh ...      # also keep the raw lines
#   MONSTER=<id> tools/sim.sh ...                 # roster monster (default: the roster default)
#
# Works on temp copies of the project (one per worker, each with its own
# isolated user:// via override.cfg), never on the real project directory.
# Prints a summary: win rate, match length, first contact, evolution timing.
#
# Timing differs from a device: headless, nothing is drawn, so the
# VisibleOnScreenNotifier2D signals never fire and no mob is ever on screen.
# Every mob ticks its AI at 20/10/3 Hz (TickScheduler NEAR/MID/FAR); on a
# device the mobs inside the camera rect tick every frame (60 Hz). Heroes and
# the monster tick every frame in both. tools/bench.sh's onscreen=1 measures
# the device's cost.
setopt NULL_GLOB
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RUNS="${1:-24}"; SIDE="${2:-heroes}"; WORKERS="${3:-6}"; CAP="${4:-660}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
# One user dir per worker AND per run: concurrent sim.sh runs must not share saves.
trap 'rm -rf "$TMP"; for i in {0..63}; do rm -rf "$HOME/Library/Application Support/evolvemobile_sim_$$_$i"; done' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/base/"
"$GODOT" --headless --import --path "$TMP/base" > "$TMP/import.log" 2>&1
for ((w = 0; w < WORKERS; w++)); do
  cp -R "$TMP/base" "$TMP/w$w"
  printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_sim_%d_%d"\n' "$$" "$w" > "$TMP/w$w/override.cfg"
done
for ((w = 0; w < WORKERS; w++)); do
  (
    for ((s = w + 1; s <= RUNS; s += WORKERS)); do
      "$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/w$w" -s res://tools/sim_match.gd -- "$s" "$SIDE" "$CAP" ${MONSTER:+monster=$MONSTER} 2>&1 \
        | grep "^SIM_RESULT " | sed 's/^SIM_RESULT //' >> "$TMP/results_$w.jsonl"
    done
  ) &
done
wait
cat "$TMP"/results_*.jsonl > "$TMP/results.jsonl" 2>/dev/null
[ -n "$OUT" ] && cp "$TMP/results.jsonl" "$OUT"
python3 "$SRC/tools/sim_summary.py" "$TMP/results.jsonl" "$RUNS"
