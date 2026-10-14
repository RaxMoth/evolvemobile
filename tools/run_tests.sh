#!/bin/zsh
# Headless test run on a throwaway copy of the project.
#  - never touches the real save file: override.cfg points user:// at
#    "evolvemobile_tests" (test/test_meta_skills.gd refuses to run otherwise)
#  - never lets a newer editor re-import/migrate the real project
# Usage: tools/run_tests.sh          (GODOT=/path/to/godot to override the binary)
set -e
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_tests"\n' > "$TMP/proj/override.cfg"
rm -rf "$HOME/Library/Application Support/evolvemobile_tests"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1 || true
set +e
"$GODOT" --headless --path "$TMP/proj" -s res://test/run_tests.gd > "$TMP/run.log" 2>&1
STATUS=$?
grep -v "Could not create child process" "$TMP/run.log"
if grep -q "SCRIPT ERROR\|ERROR:" "$TMP/run.log"; then echo "(script errors above)"; exit 1; fi
exit $STATUS
