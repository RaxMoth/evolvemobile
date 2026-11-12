#!/bin/zsh
# Headless compile check on a throwaway copy of the project (see tools/lint_all.gd).
# Usage: tools/lint.sh            (GODOT=/path/to/godot to override the binary)
# Exit 1 on any script that fails to load/compile. Engine-internal ERROR lines
# during import (e.g. "!thread.is_started()") are not script problems.
#
# GDScript warnings are errors here: every warning the project leaves at
# "warn" (tools/list_warnings.gd) is set to "error" in the copy's
# override.cfg (never in project.godot), so a warning fails the lint as a
# "Parse Error ... (Warning treated as error.)". Godot 4.7 has no single
# "treat warnings as errors" switch. The project's ignored warnings (the
# untyped / unsafe family) stay ignored, as in the editor.
#
# The lint must reach lint_all.gd's "LINT DONE" line with Godot exiting 0: a
# missing binary, a crash or a killed run fails it instead of reading as
# errors=0.
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
tool_tmp
USERDIR="evolvemobile_lint_$$"
tool_clean "$HOME/Library/Application Support/$USERDIR"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
# Autoloads run during the lint (PersistedData loads/migrates, AnalyticsSink writes):
# keep them away from the real user:// directory.
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' "$USERDIR" > "$TMP/proj/override.cfg"
run_godot "$TMP/import.log" --headless --import --path "$TMP/proj"
run_godot "$TMP/warnings.log" --headless --path "$TMP/proj" -s res://tools/list_warnings.gd
WARNINGS=(${=$(sed -n 's/^WARNINGS //p' "$TMP/warnings.log")})
if (( ${#WARNINGS} == 0 )); then
  echo "lint did not start: tools/list_warnings.gd listed no GDScript warning ($GODOT):" >&2
  tail -20 "$TMP/warnings.log" >&2
  exit 1
fi
{ printf '\n[debug]\n'; for w in $WARNINGS; do printf 'gdscript/warnings/%s=2\n' "$w"; done } >> "$TMP/proj/override.cfg"
run_godot "$TMP/lint.log" --headless --path "$TMP/proj" -s res://tools/lint_all.gd
LINT_RC=$?
if ! grep "^LINT DONE" "$TMP/lint.log" || [ "$LINT_RC" != 0 ]; then
  echo "lint did not finish (Godot exit $LINT_RC: crashed or killed?): $GODOT" >&2
  tail -20 "$TMP/lint.log" >&2
  exit 1
fi
# The import pass loads the project theme (gui/theme/custom) at startup, before
# it has imported the theme's font and SVGs on a copy whose .godot lacks them:
# those "[ext_resource] referenced non-existent resource" lines are import
# order, not broken files. lint_all.gd loads every resource after the import,
# so a resource that really is broken still fails in lint.log.
{ grep -h "SCRIPT ERROR\|Parse Error\|LINT:\|Failed to load script" "$TMP/lint.log"
  grep -h "SCRIPT ERROR\|Parse Error\|LINT:\|Failed to load script" "$TMP/import.log" |
    grep -v "Parse Error: \[ext_resource\] referenced non-existent resource"
} > "$TMP/errors.log"
ERRS=$(grep -c "" "$TMP/errors.log")
echo "errors=$ERRS"
head -30 "$TMP/errors.log"
[ "$ERRS" = "0" ]
