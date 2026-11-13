#!/bin/zsh
# Headless test run on a throwaway copy of the project.
#  - never touches the real save file: override.cfg points user:// at
#    "evolvemobile_tests_<pid>" (tests that touch the save refuse to run unless
#    the user dir contains "evolvemobile_tests"); one dir per run, so concurrent
#    runs cannot wipe each other's save files
#  - never lets a newer editor re-import/migrate the real project
#  - runs at a fixed 60 fps with no frame cap (as sim.sh/bench.sh do): every
#    delta is 1/60 s and game time runs ahead of the wall clock, so a test that
#    needs real time (AudioManager's msec rate limit) must wait with OS.delay_msec.
#    For the same reason override.cfg turns off the navigation server's async
#    map/region iterations (as tools/sim_trace.sh does): on a worker thread a map
#    sync takes wall-clock time, while tests wait a fixed number of physics frames
#  - test/run_tests.gd fails a test that hit a SCRIPT ERROR (saying where it
#    came from) or an engine ERROR it did not announce (TestCase.expect_error),
#    fails a run whose names match no test file, counts skipped
#    tests apart from the passed ones and stops a test that runs longer than
#    its time limit (TIMEOUT <test>), so a regression that loops forever fails
#    the run instead of hanging it; TOOL_TIME_LIMIT_S (default 3600 s here)
#    bounds the whole Godot run as a second net (exit 124)
# Usage: tools/run_tests.sh [name ...]   (GODOT=/path/to/godot to override the binary)
#   names: run only the test files whose name contains one, e.g. "minimap" or "test_gorrak"
set -e
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
tool_time_limit 3600
tool_tmp
USERDIR="evolvemobile_tests_$$"
tool_clean "$HOME/Library/Application Support/$USERDIR"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n\n[navigation]\nworld/map_use_async_iterations=false\nworld/region_use_async_iterations=false\n' "$USERDIR" > "$TMP/proj/override.cfg"
run_godot "$TMP/import.log" --headless --import --path "$TMP/proj" || true
set +e
run_godot "$TMP/run.log" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/proj" -s res://test/run_tests.gd -- "$@"
STATUS=$?
grep -v "Could not create child process" "$TMP/run.log"
# The runner fails a test on its own SCRIPT ERROR or unannounced engine
# ERROR; this second net also catches a SCRIPT ERROR outside any test. Some
# tests provoke engine ERROR lines on purpose (e.g. loading a corrupt save
# file, announced with expect_error), so here only SCRIPT ERROR lines and
# broken scene wiring fail the run. Broken wiring only shows up at runtime, as
# an engine ERROR when a signal is connected ("nonexistent signal") or fires
# ("Method not found"; Godot 4.7.2 stays silent there) or when a state-chart
# transition is taken ("is not a state"). tools/lint_all.gd checks the scenes
# statically.
if grep -q "SCRIPT ERROR" "$TMP/run.log"; then echo "(script errors above)"; exit 1; fi
if grep -qE "Method not found|nonexistent signal|is not a state" "$TMP/run.log"; then echo "(broken scene wiring above)"; exit 1; fi
if [ "$STATUS" != 0 ] && ! grep -q "^== .* passed, .* failed, .* skipped ==" "$TMP/run.log"; then
  echo "(the runner did not finish$(rc_note "$STATUS"))"
fi
exit $STATUS
