#!/bin/zsh
# Self-test of the headless tools: each one must fail when it should, pass
# when it should, and leave nothing behind when it is killed. Runs the tools
# against a fake Godot on a tiny stand-in project (the repo's tools/ and an
# empty project.godot), so no real Godot starts; about half a minute.
#
#   tools/selftest.sh     one line per check; exit 1 when any check fails
#
# Run it after changing a tool (tools/*.sh, tool_env.zsh, monster_env.zsh,
# sim_summary.py). What the real Godot side does (a SCRIPT ERROR in a real
# script, a warning, a test that loops forever) is checked by planting it in
# a copy of the project: README "Headless Tools".
SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
P="$WORK/proj"
mkdir -p "$P/tools"
cp "$SRC"/tools/*.sh "$SRC"/tools/*.zsh "$SRC"/tools/*.py "$P/tools/"
: > "$P/project.godot"
FAKE="$WORK/godot"
export FAKE_LOG="$WORK/fake.log"
APP_SUPPORT="$HOME/Library/Application Support"

# The fake Godot: logs "<pid> <script or import> <--path>" to $FAKE_LOG,
# creates the user:// dir its override.cfg names (as Godot would) and plays
# the -s script the way $FAKE_MODE says: ok, error (a SCRIPT ERROR; seed 2 of
# a match crashes without a result), crash, slow (runs until killed).
cat > "$FAKE" <<'FAKE_GODOT'
#!/bin/zsh
proj=""; script=""; args=()
while (( $# )); do
  case "$1" in
    --path) proj="$2"; shift 2 ;;
    -s) script="$2"; shift 2 ;;
    --) shift; args=("$@"); break ;;
    *) shift ;;
  esac
done
print -r -- "$$ ${script:-import} $proj" >> "$FAKE_LOG"
ud="$(sed -n 's/^config\/custom_user_dir_name="\(.*\)"$/\1/p' "$proj/override.cfg" 2> /dev/null)"
[ -n "$ud" ] && mkdir -p "$HOME/Library/Application Support/$ud"
[ "$FAKE_MODE" = slow ] && [[ "$script" == res://(tools/(lint_all|sim_match|bench_match)|test/run_tests).gd ]] && exec sleep 60
case "$script" in
  res://tools/list_monsters.gd) echo "MONSTER_IDS grount nyxa" ;;
  res://tools/list_warnings.gd) echo "WARNINGS unused_variable shadowed_variable" ;;
  res://tools/lint_all.gd)
    case "$FAKE_MODE" in
      crash) echo "handle_crash: Program crashed with signal 11"; exit 139 ;;
      error) echo "SCRIPT ERROR: Parse Error: planted"; echo "LINT DONE scripts=1 warnings_as_errors=2" ;;
      *) grep -q '^gdscript/warnings/shadowed_variable=2$' "$proj/override.cfg" || exit 1
         echo "LINT DONE scripts=1 warnings_as_errors=2" ;;
    esac ;;
  res://test/run_tests.gd)
    case "$FAKE_MODE" in
      crash) exit 139 ;;
      error) echo "SCRIPT ERROR: planted"; echo "== 1 passed, 0 failed, 0 skipped ==" ;;
      *) echo "== 1 passed, 0 failed, 0 skipped ==" ;;
    esac ;;
  res://tools/sim_match.gd)
    seed="$args[1]"; side="$args[2]"
    if [ "$FAKE_MODE" = error ]; then
      [ "$seed" = 2 ] && exit 139
      echo "SCRIPT ERROR: planted"
    fi
    if (( ${args[(Ie)trace]} )); then
      echo "SIM_TRACE 60 ${seed}0"
      echo "SIM_TRACE_END 120 end Heroes ${seed}1"
    fi
    echo "SIM_RESULT {\"seed\": $seed, \"side\": \"$side\", \"monster\": \"grount\", \"monster_name\": \"Grount\", \"threat\": 0, \"power\": 0, \"reason\": \"end\", \"winner\": \"Heroes\", \"t\": 300.0, \"game_clock\": 300.0, \"monster_stage\": 2, \"heroes_alive\": 4, \"hero_deaths\": [], \"evolutions\": [], \"first_contact\": 100.0, \"hero_dmg_to_monster\": 1000, \"monster_dmg_to_heroes\": 500, \"mob_kills_monster\": 10, \"mob_kills_heroes\": 20, \"monster_dmg_taken\": {\"heroes\": 1000.0, \"mobs\": 0.0, \"other\": 0.0}, \"monster_killer\": \"heroes\"}" ;;
  res://tools/bench_match.gd)
    [ "$FAKE_MODE" = error ] && exit 1
    echo "BENCH_RESULT {\"seed\": $args[1], \"monster\": \"grount\", \"frames\": 10, \"ended_at_frame\": -1, \"multiplier\": 1, \"frame_ms_mean\": 1.0, \"frame_ms_p50\": 1.0, \"frame_ms_p95\": 1.0, \"frame_ms_p99\": 1.0, \"frame_ms_max\": 1.0, \"frame_peak_ms\": 1.0, \"lod_counts\": {}}" ;;
esac
exit 0
FAKE_GODOT
chmod +x "$FAKE"

FAILS=0
# expect <name> <exit code> <regex in stdout/stderr, or ""> <cmd...>
expect() {
  local name="$1" want="$2" pattern="$3"
  shift 3
  : > "$FAKE_LOG"
  "$@" > "$WORK/out.txt" 2> "$WORK/err.txt"
  local rc=$?
  if [ "$rc" = "$want" ] && { [ -z "$pattern" ] || cat "$WORK/out.txt" "$WORK/err.txt" | grep -qE -- "$pattern"; }; then
    echo "ok    $name (exit $rc)"
  else
    echo "FAIL  $name: exit $rc, expected $want${pattern:+ and /$pattern/}"
    cat "$WORK/out.txt" "$WORK/err.txt" | tail -6 | sed 's/^/        /'
    FAILS=$((FAILS + 1))
  fi
}

# killed <name> <starts> <cmd...>: start the tool with FAKE_MODE=slow, TERM it
# once <starts> slow scripts run, then nothing may be left: no fake running,
# no new start, no temp copy, no user:// dir of that tool's pid.
killed() {
  local name="$1" starts="$2"
  shift 2
  : > "$FAKE_LOG"
  FAKE_MODE=slow "$@" > "$WORK/out.txt" 2> "$WORK/err.txt" &
  local tool=$! i
  for ((i = 0; i < 150; i++)); do
    (( $(grep -cE ' res://(tools/(lint_all|sim_match|bench_match)|test/run_tests)\.gd ' "$FAKE_LOG") >= starts )) && break
    sleep 0.1
  done
  kill -TERM $tool
  wait $tool
  local rc=$?
  local lines=$(grep -c "" "$FAKE_LOG")
  sleep 1
  local problems=()
  [ "$rc" = 143 ] || problems+=("exit $rc")
  (( $(grep -c "" "$FAKE_LOG") == lines )) || problems+=("a match started after the kill")
  local pid script proj
  while read -r pid script proj; do
    kill -0 $pid 2> /dev/null && problems+=("fake $pid ($script) still runs")
    [ -n "$proj" ] && [ -e "$proj" ] && problems+=("copy $proj left")
  done < "$FAKE_LOG"
  local left=("$APP_SUPPORT"/evolvemobile_*_${tool}(N) "$APP_SUPPORT"/evolvemobile_*_${tool}_*(N))
  (( ${#left} )) && problems+=("user dirs left: ${left[*]}")
  if (( ${#problems} == 0 )) && (( lines > 0 )); then
    echo "ok    $name (TERM after $starts slow runs: exit 143, nothing left)"
  else
    echo "FAIL  $name: ${problems[*]:-no slow run started}"
    for pid script proj in $(cat "$FAKE_LOG"); do kill $pid 2> /dev/null; done
    FAILS=$((FAILS + 1))
  fi
}

T="$P/tools"
export GODOT="$FAKE"
expect "lint: no Godot binary" 2 "no such program" env GODOT=/nonexistent/godot "$T/lint.sh"
expect "lint: Godot crashes before LINT DONE" 1 "lint did not finish" env FAKE_MODE=crash "$T/lint.sh"
expect "lint: a SCRIPT ERROR" 1 "errors=1" env FAKE_MODE=error "$T/lint.sh"
expect "lint: clean, warnings set to errors" 0 "errors=0" env FAKE_MODE=ok "$T/lint.sh"
expect "tests: a SCRIPT ERROR" 1 "script errors above" env FAKE_MODE=error "$T/run_tests.sh"
expect "tests: the runner crashes" 139 "did not finish" env FAKE_MODE=crash "$T/run_tests.sh"
expect "tests: clean" 0 "1 passed" env FAKE_MODE=ok "$T/run_tests.sh"
expect "sim: a side that is not heroes or monster" 2 "heroes or monster" "$T/sim.sh" 2 monsters 1 60
expect "sim: a SAVE file that is not there" 2 "no such file" env SAVE="$WORK/missing.cfg" "$T/sim.sh" 2 heroes 1 60
expect "sim: a step setting out of range" 2 "SPEED is 0-2" env SPEED=3 "$T/sim.sh" 2 heroes 1 60
expect "sim: a SCRIPT ERROR and a crashed seed" 1 "seed 2: failed .*no result" env FAKE_MODE=error "$T/sim.sh" 2 heroes 2 60
expect "sim: clean" 0 "runs: 4/4" env FAKE_MODE=ok "$T/sim.sh" 4 heroes 2 60
expect "trace: a side that is not heroes or monster" 2 "heroes or monster" "$T/sim_trace.sh" "1" "hero"
expect "trace: JOBS=0" 2 "JOBS" env JOBS=0 "$T/sim_trace.sh"
expect "trace: a SCRIPT ERROR" 1 "seed 1 heroes: failed" env FAKE_MODE=error "$T/sim_trace.sh" "1" "heroes"
expect "trace: JOBS=2 keeps the argument order" 0 "^1 heroes SIM_TRACE 60 10" env FAKE_MODE=ok JOBS=2 "$T/sim_trace.sh"
order="$(cut -d' ' -f1,2 "$WORK/out.txt" | uniq | tr '\n' ' ')"
if [ "$order" = "1 heroes 1 monster 2 heroes 2 monster 3 heroes 3 monster " ]; then
  echo "ok    trace: lines in seed x side order"
else
  echo "FAIL  trace: lines in the order '$order'"
  FAILS=$((FAILS + 1))
fi
expect "bench: a run without a result" 1 "run 1 failed" env FAKE_MODE=error "$T/bench.sh" 1 1 10 0
expect "bench: clean" 0 "runs: 2/2" env FAKE_MODE=ok "$T/bench.sh" 2 1 10 0
killed "sim: killed mid-run" 2 "$T/sim.sh" 4 heroes 2 60
killed "trace: killed mid-run" 2 env JOBS=2 "$T/sim_trace.sh"
killed "lint: killed mid-run" 1 "$T/lint.sh"
killed "tests: killed mid-run" 1 "$T/run_tests.sh"
killed "bench: killed mid-run" 1 "$T/bench.sh" 2 1 10 0
if (( FAILS )); then
  echo "selftest: $FAILS check(s) failed"
  exit 1
fi
echo "selftest: all checks passed"
