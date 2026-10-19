#!/bin/zsh
# Headless compile check on a throwaway copy of the project (see tools/lint_all.gd).
# Usage: tools/lint.sh            (GODOT=/path/to/godot to override the binary)
# Exit 1 on any script that fails to load/compile. Engine-internal ERROR lines
# during import (e.g. "!thread.is_started()") are not script problems.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
LINT_USER="$HOME/Library/Application Support/evolvemobile_lint"
trap 'rm -rf "$TMP" "$LINT_USER"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
# Autoloads run during the lint (PersistedData loads/migrates, AnalyticsSink writes):
# keep them away from the real user:// directory.
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_lint"\n' > "$TMP/proj/override.cfg"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1
"$GODOT" --headless --path "$TMP/proj" -s res://tools/lint_all.gd > "$TMP/lint.log" 2>&1
grep "LINT DONE" "$TMP/lint.log"
ERRS=$(grep -c "SCRIPT ERROR\|Parse Error\|LINT:\|Failed to load script" "$TMP/lint.log" "$TMP/import.log" | awk -F: '{s+=$2} END {print s}')
echo "errors=$ERRS"
grep -h "SCRIPT ERROR\|Parse Error\|LINT:\|Failed to load script" "$TMP/lint.log" "$TMP/import.log" | head -30
[ "$ERRS" = "0" ]
