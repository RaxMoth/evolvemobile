#!/bin/zsh
# Headless balance simulation: N seeded auto-play matches in parallel.
#
#   tools/sim.sh [runs=24] [side=heroes|monster] [workers=6] [cap_seconds=660]
#   OUT=/path/results.jsonl tools/sim.sh ...      # also keep the raw lines (every monster's)
#   MONSTER=<id> tools/sim.sh ...                 # one roster monster (default: the roster default)
#   MONSTER=all tools/sim.sh ...                  # every roster monster in turn, one summary each
#   SAVE=/path/save.cfg tools/sim.sh ...          # every match starts from this save (skill ranks,
#                                                 # capstones); default: a fresh save
#
# Works on temp copies of the project (one per worker, each with its own
# isolated user:// via override.cfg), never on the real project directory.
# Prints a summary per monster: win rate, match length, first contact,
# evolution timing. An unknown MONSTER id fails (exit 2) instead of quietly
# playing the default monster.
#
# Reproducible: the copies' override.cfg turns off the navigation server's
# asynchronous map and region iterations, as tools/sim_trace.sh does, and every
# seed starts from a fresh user:// (or SAVE). The same tree gives the same
# results on every run, whatever the CPU load or worker count, and seed s plays
# the match of sim_trace.sh's seed s. With async iterations on, a map update
# lands a frame early or late with CPU load: 24 seeds of identical code gave
# 17% and 33% hero wins on two runs.
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
source "$SRC/tools/monster_env.zsh"
TMP="$(mktemp -d)"
# One user dir per worker AND per run: concurrent sim.sh runs must not share saves.
USER_DIRS="$HOME/Library/Application Support/evolvemobile_sim_$$"
trap 'rm -rf "$TMP"; for i in {0..63}; do rm -rf "${USER_DIRS}_$i"; done' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/base/"
"$GODOT" --headless --import --path "$TMP/base" > "$TMP/import.log" 2>&1
for ((w = 0; w < WORKERS; w++)); do
  cp -R "$TMP/base" "$TMP/w$w"
  printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_sim_%d_%d"\n\n[navigation]\nworld/map_use_async_iterations=false\nworld/region_use_async_iterations=false\n' "$$" "$w" > "$TMP/w$w/override.cfg"
done
resolve_monsters "$TMP/w0" || exit 2
for m in "${MONSTERS[@]}"; do
  res="$TMP/results_${m:-default}"
  mkdir -p "$res"
  for ((w = 0; w < WORKERS; w++)); do
    (
      for ((s = w + 1; s <= RUNS; s += WORKERS)); do
        # A match writes its rewards back: every seed starts from a fresh save
        # (or the given one) again, so a seed's result never depends on which
        # worker played it or what that worker played before.
        rm -rf "${USER_DIRS}_$w"
        if [ -n "$SAVE" ]; then
          mkdir -p "${USER_DIRS}_$w"
          cp "$SAVE" "${USER_DIRS}_$w/save.cfg"
        fi
        "$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/w$w" -s res://tools/sim_match.gd -- "$s" "$SIDE" "$CAP" ${m:+monster=$m} 2>&1 \
          | grep "^SIM_RESULT " | sed 's/^SIM_RESULT //' >> "$res/w$w.jsonl"
      done
    ) &
  done
  wait
  cat "$res"/w*.jsonl > "$res.jsonl" 2>/dev/null
  cat "$res.jsonl" >> "$TMP/results.jsonl"
done
[ -n "$OUT" ] && cp "$TMP/results.jsonl" "$OUT"
STATUS=0
first=1
for m in "${MONSTERS[@]}"; do
  (( first )) || echo
  first=0
  python3 "$SRC/tools/sim_summary.py" "$TMP/results_${m:-default}.jsonl" "$RUNS" || STATUS=1
done
exit $STATUS
