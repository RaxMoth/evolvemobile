#!/bin/zsh
# Determinism trace of the headless sim: the exact-equivalence check for
# changes that must not alter gameplay (pure refactors).
#
#   tools/sim_trace.sh [seeds="1 2 3"] [sides="heroes monster"] [cap_seconds=660] > trace.txt
#   BASELINE=/path/parent.txt tools/sim_trace.sh > trace.txt   # also diff, exit 1 on any difference
#
# Runs every seed x side as one full match (tools/sim_match.gd ... trace), all in
# parallel, each on its own temp copy with a fresh user:// (override.cfg), never
# on the real project directory. stdout gets only the trace lines, prefixed with
# "<seed> <side>", in argument order:
#   <seed> <side> SIM_TRACE <frame> <hash>                      every 60 frames
#   <seed> <side> SIM_TRACE_END <frame> <reason> <winner> <hash>
# The same tree gives byte-identical output from the first line (frame 60) on,
# also under heavy CPU load. That needs the copies' override.cfg to turn off the
# navigation server's asynchronous map and region iterations (temp copies only):
# built on worker threads, a map update lands a frame early or late with CPU load
# and GameUtils branches on map_get_iteration_id(); with them on, two runs of one
# seed diverged from frame 180. Exit 1 if a run hit a SCRIPT ERROR or did not
# finish, or (with BASELINE) if the trace differs.
setopt NULL_GLOB
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SEEDS=(${=${1:-1 2 3}}); SIDES=(${=${2:-heroes monster}}); CAP="${3:-660}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
USER_DIRS="$HOME/Library/Application Support/evolvemobile_trace_$$"
trap 'rm -rf "$TMP" "$USER_DIRS"_*' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/base/"
"$GODOT" --headless --import --path "$TMP/base" > "$TMP/import.log" 2>&1
run=0
for s in $SEEDS; do
  for side in $SIDES; do
    run=$((run + 1))
    dir="$TMP/run_${s}_$side"
    cp -R "$TMP/base" "$dir"
    printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_trace_%s_%d"\n\n[navigation]\nworld/map_use_async_iterations=false\nworld/region_use_async_iterations=false\n' "$$" "$run" > "$dir/override.cfg"
    rm -rf "${USER_DIRS}_$run"
    "$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$dir" \
      -s res://tools/sim_match.gd -- "$s" "$side" "$CAP" trace > "$dir.log" 2>&1 &
  done
done
wait
STATUS=0
for s in $SEEDS; do
  for side in $SIDES; do
    log="$TMP/run_${s}_$side.log"
    if grep -q "SCRIPT ERROR" "$log" || ! grep -q "^SIM_TRACE_END " "$log"; then
      echo "seed $s $side: failed" >&2
      grep -m 5 -A 2 "SCRIPT ERROR" "$log" >&2
      STATUS=1
    fi
    grep -E "^SIM_TRACE(_END)? " "$log" | sed "s/^/$s $side /" >> "$TMP/trace.txt"
  done
done
cat "$TMP/trace.txt"
if [ -n "$BASELINE" ]; then
  if cmp -s "$BASELINE" "$TMP/trace.txt"; then
    echo "trace identical to $BASELINE ($(wc -l < "$TMP/trace.txt" | tr -d ' ') lines)" >&2
  else
    first="$(cmp "$BASELINE" "$TMP/trace.txt" 2>&1 | grep -oE 'line [0-9]+' | grep -oE '[0-9]+')"
    echo "trace DIFFERS from $BASELINE (first difference at line ${first:-?}):" >&2
    if [ -n "$first" ]; then
      echo "  baseline: $(sed -n "${first}p" "$BASELINE")" >&2
      echo "  this run: $(sed -n "${first}p" "$TMP/trace.txt")" >&2
    fi
    STATUS=1
  fi
fi
exit $STATUS
