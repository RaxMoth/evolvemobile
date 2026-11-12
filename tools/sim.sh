#!/bin/zsh
# Headless balance simulation: N seeded auto-play matches in parallel.
#
#   tools/sim.sh [runs=24] [side=heroes|monster] [workers=6] [cap_seconds=660]
#   OUT=/path/results.jsonl tools/sim.sh ...      # also keep the raw lines (every monster's)
#   MONSTER=<id> tools/sim.sh ...                 # one roster monster (default: the roster default)
#   MONSTER=all tools/sim.sh ...                  # every roster monster in turn, one summary each
#   SAVE=/path/save.cfg tools/sim.sh ...          # every match starts from this save (skill ranks,
#                                                 # capstones); default: a fresh save
#   THREAT=<0-4> tools/sim.sh ...                 # Opponent Threat parity check: both sides hold
#                                                 # their AI build at that threat
#   THREAT="0 2 4" | THREAT=all tools/sim.sh ...  # several threats (all = 0..4), one summary each
#   SPEED=<0-2> FPS=<n> LOD=off tools/sim.sh ...  # the step-size check (see "Timing" below)
#
# Opponent Threat (README): the played side applies the save's trees, the AI
# opponent the AI build at threat T = min(4, floor(P / 6)), P = the played
# side's power ranks. THREAT=N is the parity check: the AI opponent is put at
# threat N (MetaSkillManager.threat_override) and each seed's fresh save gets
# the played side's own AI build at N (MetaSkillManager.side_ai_build: 3N
# entries of each played character tree's ai_build_order, 2N of its base
# tree's). With SAVE the save's power ranks decide the threat (the summary
# prints it); SAVE and THREAT together are refused (exit 2).
#
# Works on temp copies of the project (one per worker, each with its own
# isolated user:// via override.cfg), never on the real project directory.
# Prints a summary per threat and monster: win rate, match length, first
# contact, evolution timing. An unknown MONSTER id fails (exit 2) instead of
# quietly playing the default monster; so do a THREAT outside 0-4, a side
# other than heroes or monster and a SAVE file that is not there.
#
# Exit 1 when a match hit a SCRIPT ERROR or ended without a result: the seed
# and its first error lines go to stderr (the summary still prints, over the
# matches that did finish). A kill (TERM, INT, HUP) stops the workers and
# their matches and deletes the copies (tools/tool_env.zsh).
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
#
# The step-size check plays what a device steps: SPEED=1 the match's base
# speed and SPEED=2 its fast setting (Engine.time_scale 1.2 / 2.4, so a frame
# covers time_scale / FPS game seconds: 1/50 and 1/25 at 60 fps), FPS=<n> the
# frame rate (FPS=30 SPEED=2: 1/12.5, fast on a 30 fps phone), LOD=off ticks
# every mob every frame (TickScheduler.lod_enabled false), as a device ticks
# the mobs on screen. Defaults: SPEED=0 FPS=60 LOD=on, every frame 1/60 game
# second (the numbers every table in the README was measured with). Times in
# the results stay game seconds; each row has "step_hz" and "lod".
setopt NULL_GLOB
RUNS="${1:-24}"; SIDE="${2:-heroes}"; WORKERS="${3:-6}"; CAP="${4:-660}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
source "$SRC/tools/monster_env.zsh"
if [[ "$SIDE" != (heroes|monster) ]]; then
  echo "side=$SIDE: heroes or monster" >&2
  exit 2
fi
SPEED="${SPEED:-0}"; FPS="${FPS:-60}"; LOD="${LOD:-on}"
if [[ ! "$SPEED" =~ '^[0-2]$' ]] || [[ ! "$FPS" =~ '^[1-9][0-9]*$' ]] || [[ "$LOD" != (on|off) ]]; then
  echo "SPEED=$SPEED FPS=$FPS LOD=$LOD: SPEED is 0-2, FPS a frame rate, LOD on or off" >&2
  exit 2
fi
STEP_ARGS=()
[ "$SPEED" != 0 ] && STEP_ARGS+=("speed=$SPEED")
[ "$FPS" != 60 ] && STEP_ARGS+=("fps=$FPS")
[ "$LOD" = off ] && STEP_ARGS+=("lod=off")
if [ -n "$SAVE" ] && [ ! -f "$SAVE" ]; then
  echo "SAVE=$SAVE: no such file" >&2
  exit 2
fi
# THREATS: ("") = no threat= argument (the save decides), else 0..4 each.
THREATS=("")
if [ -n "$THREAT" ]; then
  if [ -n "$SAVE" ]; then
    echo "SAVE and THREAT both set the played side's ranks; use one (with SAVE the save's power ranks decide the threat)" >&2
    exit 2
  fi
  [ "$THREAT" = all ] && THREATS=(0 1 2 3 4) || THREATS=(${=THREAT//,/ })
  for t in $THREATS; do
    if [[ ! "$t" =~ '^[0-4]$' ]]; then
      echo "THREAT=$THREAT: each threat is 0-4 (or THREAT=all)" >&2
      exit 2
    fi
  done
fi
tool_tmp
# One user dir per worker AND per run: concurrent sim.sh runs must not share saves.
USER_DIRS="$HOME/Library/Application Support/evolvemobile_sim_$$"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/base/"
run_godot "$TMP/import.log" --headless --import --path "$TMP/base"
for ((w = 0; w < WORKERS; w++)); do
  cp -R "$TMP/base" "$TMP/w$w"
  printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_sim_%d_%d"\n\n[navigation]\nworld/map_use_async_iterations=false\nworld/region_use_async_iterations=false\n' "$$" "$w" > "$TMP/w$w/override.cfg"
  tool_clean "${USER_DIRS}_$w"
done
resolve_monsters "$TMP/w0" || exit 2
STATUS=0
for t in "${THREATS[@]}"; do
  for m in "${MONSTERS[@]}"; do
    res="$TMP/results_${t:-save}_${m:-default}"
    mkdir -p "$res"
    for ((w = 0; w < WORKERS; w++)); do
      (
        tool_worker
        for ((s = w + 1; s <= RUNS; s += WORKERS)); do
          # A match writes its rewards back: every seed starts from a fresh save
          # (or the given one) again, so a seed's result never depends on which
          # worker played it or what that worker played before.
          rm -rf "${USER_DIRS}_$w"
          if [ -n "$SAVE" ]; then
            mkdir -p "${USER_DIRS}_$w"
            cp "$SAVE" "${USER_DIRS}_$w/save.cfg"
          fi
          run_godot "$res/seed_$s.log" --headless --fixed-fps "$FPS" --max-fps 0 --path "$TMP/w$w" \
            -s res://tools/sim_match.gd -- "$s" "$SIDE" "$CAP" ${m:+monster=$m} ${t:+threat=$t} "${STEP_ARGS[@]}"
        done
      ) &
      TOOL_PIDS+=($!)
    done
    wait
    TOOL_PIDS=()
    # Seed order; a match with a SCRIPT ERROR (an ability that errors on every
    # cast still lets the match finish) or without a result fails the run.
    : > "$res.jsonl"
    for ((s = 1; s <= RUNS; s++)); do
      log="$res/seed_$s.log"
      sed -n 's/^SIM_RESULT //p' "$log" >> "$res.jsonl"
      if grep -q "SCRIPT ERROR" "$log" || ! grep -q "^SIM_RESULT " "$log"; then
        echo "${t:+threat $t }${m:+$m }seed $s: failed ($(grep -c "SCRIPT ERROR" "$log") script errors$(grep -q "^SIM_RESULT " "$log" || echo ", no result"))" >&2
        { grep -m 5 -A 2 "SCRIPT ERROR" "$log" || tail -5 "$log"; } >&2
        STATUS=1
      fi
    done
    cat "$res.jsonl" >> "$TMP/results.jsonl"
  done
done
[ -n "$OUT" ] && cp "$TMP/results.jsonl" "$OUT"
first=1
for t in "${THREATS[@]}"; do
  for m in "${MONSTERS[@]}"; do
    (( first )) || echo
    first=0
    python3 "$SRC/tools/sim_summary.py" "$TMP/results_${t:-save}_${m:-default}.jsonl" "$RUNS" || STATUS=1
  done
done
exit $STATUS
