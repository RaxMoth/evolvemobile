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
# Usage: tools/run_tests.sh          (GODOT=/path/to/godot to override the binary)
set -e
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
USERDIR="evolvemobile_tests_$$"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/$USERDIR"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n\n[navigation]\nworld/map_use_async_iterations=false\nworld/region_use_async_iterations=false\n' "$USERDIR" > "$TMP/proj/override.cfg"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1 || true
set +e
"$GODOT" --headless --fixed-fps 60 --max-fps 0 --path "$TMP/proj" -s res://test/run_tests.gd > "$TMP/run.log" 2>&1
STATUS=$?
grep -v "Could not create child process" "$TMP/run.log"
# Only SCRIPT ERROR lines fail the run: some tests provoke engine ERROR
# lines on purpose (e.g. loading a corrupt save file).
if grep -q "SCRIPT ERROR" "$TMP/run.log"; then echo "(script errors above)"; exit 1; fi
exit $STATUS
