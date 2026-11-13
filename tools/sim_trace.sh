#!/bin/zsh
# Determinism trace of the headless sim: the exact-equivalence check for
# changes that must not alter gameplay (pure refactors).
#
#   tools/sim_trace.sh [seeds="1 2 3"] [sides="heroes monster"] [cap_seconds=660] > trace.txt
#   BASELINE=/path/parent.txt tools/sim_trace.sh > trace.txt   # also diff, exit 1 on any difference
#   RIGS_AWAKE=1 tools/sim_trace.sh ...   # every CharacterRig animates, as on a device; must not change the trace
#                                         # (RIGS_AWAKE=0 or unset: asleep, as headless)
#   MONSTER=<id> tools/sim_trace.sh ...   # one roster monster (default: the roster default, the gate's baseline)
#   MONSTER=all tools/sim_trace.sh ...    # every roster monster in turn; each line gets a "<id> " prefix
#
# Per-monster baselines (tools/baselines/trace_<id>.txt, the plain trace of
# MONSTER=<id> with the default seeds, sides and cap; take them with
# MONSTER=all so every monster is covered):
#   MONSTER=all BASELINE_DIR=tools/baselines tools/sim_trace.sh > trace.txt
#       diff each monster with its trace_<id>.txt, exit 1 on a difference or a missing baseline
#   MONSTER=all RECORD_DIR=tools/baselines tools/sim_trace.sh > /dev/null
#       (re)write them: after a commit that changes gameplay on purpose, or when a monster lands
# A refactor must reproduce the committed baselines byte for byte; a gameplay
# change re-records them in the same commit. The hashes depend on the engine
# build and the CPU: re-record after an engine upgrade or on another machine.
#
# Runs every monster x seed x side as one full match (tools/sim_match.gd ...
# trace), JOBS at a time (default 2; JOBS=6 runs a monster's six default
# matches at once on a machine with the memory for it), each worker on its own
# temp copy with a fresh user:// (override.cfg) for every match, never on the
# real project directory. A seed or side given twice plays twice (two runs of
# one seed: a determinism check within one call). stdout gets only the trace
# lines, prefixed with "<seed> <side>", in argument order whatever JOBS is:
#   <seed> <side> SIM_TRACE <frame> <hash>                      every 60 frames
#   <seed> <side> SIM_TRACE_END <frame> <reason> <winner> <hash>
# The same tree gives byte-identical output from the first line (frame 60) on,
# also under heavy CPU load. That needs the copies' override.cfg to turn off the
# navigation server's asynchronous map and region iterations (temp copies only):
# built on worker threads, a map update lands a frame early or late with CPU load
# and GameUtils branches on map_get_iteration_id(); with them on, two runs of one
# seed diverged from frame 180. Exit 1 if a run hit a SCRIPT ERROR, did not
# finish or its Godot exited non-zero (a crash after SIM_TRACE_END, in the
# match-end settlement or the teardown), or (with BASELINE / BASELINE_DIR) if
# the trace differs; exit 2 on an unknown MONSTER id, a side other than heroes
# or monster, a bad cap or a bad JOBS. A match still running after
# TOOL_TIME_LIMIT_S (default: 3 s per capped game second, at least 1800 s; a
# match takes 15-60 s) is stopped and fails the same way. A kill (TERM, INT,
# HUP) stops the workers and their matches and deletes the copies
# (tools/tool_env.zsh).
setopt NULL_GLOB
SEEDS=(${=${1:-1 2 3}}); SIDES=(${=${2:-heroes monster}}); CAP="${3:-660}"
JOBS="${JOBS:-2}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
source "$SRC/tools/monster_env.zsh"
if [[ ! "$JOBS" =~ '^[1-9][0-9]*$' ]]; then
  echo "JOBS=$JOBS: the number of matches at a time, 1 or more" >&2
  exit 2
fi
for side in $SIDES; do
  if [[ "$side" != (heroes|monster) ]]; then
    echo "side $side: heroes or monster" >&2
    exit 2
  fi
done
if [[ ! "$CAP" =~ '^[1-9][0-9]*$' ]]; then
  echo "cap_seconds=$CAP: whole game seconds" >&2
  exit 2
fi
tool_time_limit $(( 3 * CAP > 1800 ? 3 * CAP : 1800 ))
RIGS_ARG=()
[ -n "$RIGS_AWAKE" ] && [ "$RIGS_AWAKE" != 0 ] && RIGS_ARG=(rigs_awake)
if [ -z "$MONSTER" ] && [ -n "$BASELINE_DIR$RECORD_DIR" ]; then
  echo "BASELINE_DIR / RECORD_DIR need MONSTER=<id> or MONSTER=all" >&2
  exit 2
fi
if [ -n "$RECORD_DIR" ] && [ "$SEEDS $SIDES $CAP" != "1 2 3 heroes monster 660" ]; then
  echo "RECORD_DIR records the default seeds, sides and cap only (the baselines' arguments)" >&2
  exit 2
fi
tool_tmp
USER_DIRS="$HOME/Library/Application Support/evolvemobile_trace_$$"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/base/"
run_godot "$TMP/import.log" --headless --import --path "$TMP/base"
# The roster lookup runs on base with its own user dir; every worker copy below
# replaces this override.cfg with its own.
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_trace_%s_list"\n' "$$" > "$TMP/base/override.cfg"
tool_clean "${USER_DIRS}_list"
resolve_monsters "$TMP/base" || exit 2
# Every match, monster-major in argument order; worker w plays the matches
# w+1, w+1+JOBS, ... on its own copy, with a fresh user:// for each. Match i
# writes run_<i>.log and its Godot exit code to run_<i>.rc.
RUN_M=(); RUN_S=(); RUN_SIDE=()
for m in "${MONSTERS[@]}"; do
  for s in $SEEDS; do
    for side in $SIDES; do
      RUN_M+=("$m"); RUN_S+=("$s"); RUN_SIDE+=("$side")
    done
  done
done
(( JOBS > ${#RUN_S} )) && JOBS=${#RUN_S}
for ((w = 0; w < JOBS; w++)); do
  cp -R "$TMP/base" "$TMP/w$w"
  printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_trace_%s_%d"\n\n[navigation]\nworld/map_use_async_iterations=false\nworld/region_use_async_iterations=false\n' "$$" "$w" > "$TMP/w$w/override.cfg"
  tool_clean "${USER_DIRS}_$w"
done
for ((w = 0; w < JOBS; w++)); do
  (
    tool_worker
    for ((i = w + 1; i <= ${#RUN_S}; i += JOBS)); do
      m="${RUN_M[i]}"
      rm -rf "${USER_DIRS}_$w"
      run_godot "$TMP/run_$i.log" --headless --fixed-fps 60 --max-fps 0 \
        --path "$TMP/w$w" -s res://tools/sim_match.gd -- "${RUN_S[i]}" "${RUN_SIDE[i]}" "$CAP" trace \
        "${RIGS_ARG[@]}" ${m:+monster=$m}
      echo $? > "$TMP/run_$i.rc"
    done
  ) &
  TOOL_PIDS+=($!)
done
wait
TOOL_PIDS=()
STATUS=0
i=0
for m in "${MONSTERS[@]}"; do
  tag="${m:-default}"
  : > "$TMP/trace_$tag.txt"
  for s in $SEEDS; do
    for side in $SIDES; do
      i=$((i + 1))
      log="$TMP/run_$i.log"
      rc="$(cat "$TMP/run_$i.rc" 2> /dev/null)"
      if [ "$rc" != 0 ] || grep -q "SCRIPT ERROR" "$log" || ! grep -q "^SIM_TRACE_END " "$log"; then
        echo "${m:+$m }seed $s $side: failed ($(grep -c "SCRIPT ERROR" "$log") script errors$(grep -q "^SIM_TRACE_END " "$log" || echo ", no SIM_TRACE_END")$(rc_note "$rc"))" >&2
        grep -m 5 -A 2 "SCRIPT ERROR" "$log" >&2
        STATUS=1
      fi
      grep -E "^SIM_TRACE(_END)? " "$log" | sed "s/^/$s $side /" >> "$TMP/trace_$tag.txt"
    done
  done
  if [ "$MONSTER" = all ]; then
    sed "s/^/$m /" "$TMP/trace_$tag.txt" >> "$TMP/trace.txt"
  else
    cat "$TMP/trace_$tag.txt" >> "$TMP/trace.txt"
  fi
done
cat "$TMP/trace.txt"
RUNS_OK=$(( STATUS == 0 ))
# compare <baseline> <trace>: one stderr line, return 1 when they differ.
compare() {
  if [ ! -f "$1" ]; then
    echo "no baseline $1 (record it with RECORD_DIR)" >&2
    return 1
  fi
  if cmp -s "$1" "$2"; then
    echo "trace identical to $1 ($(wc -l < "$2" | tr -d ' ') lines)" >&2
    return 0
  fi
  local first="$(cmp "$1" "$2" 2>&1 | grep -oE 'line [0-9]+' | grep -oE '[0-9]+')"
  echo "trace DIFFERS from $1 (first difference at line ${first:-?}):" >&2
  if [ -n "$first" ]; then
    echo "  baseline: $(sed -n "${first}p" "$1")" >&2
    echo "  this run: $(sed -n "${first}p" "$2")" >&2
  fi
  return 1
}
if [ -n "$BASELINE" ]; then
  compare "$BASELINE" "$TMP/trace.txt" || STATUS=1
fi
for m in "${MONSTERS[@]}"; do
  [ -n "$BASELINE_DIR" ] && { compare "$BASELINE_DIR/trace_$m.txt" "$TMP/trace_$m.txt" || STATUS=1; }
  if [ -n "$RECORD_DIR" ] && (( RUNS_OK )); then
    mkdir -p "$RECORD_DIR"
    cp "$TMP/trace_$m.txt" "$RECORD_DIR/trace_$m.txt"
    echo "recorded $RECORD_DIR/trace_$m.txt ($(wc -l < "$TMP/trace_$m.txt" | tr -d ' ') lines)" >&2
  elif [ -n "$RECORD_DIR" ]; then
    echo "not recorded $RECORD_DIR/trace_$m.txt: a run failed" >&2
  fi
done
exit $STATUS
