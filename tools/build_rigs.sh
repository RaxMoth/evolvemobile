#!/bin/zsh
# Rebuild the character rigs from <root>/<id>/src (hand-drawn SVG parts +
# rig_src.json; roots: Assets/Characters and test/fixtures) into
# <id>_sheet.svg (+ .import) and <id>_body.tscn. See tools/rig_builder.gd.
#
#   tools/build_rigs.sh [id ...]        # no id: every character with a src/
#
# Works on a temp copy with its own user:// (override.cfg), never runs Godot on
# the real project directory (the editor may have it open): builds there,
# imports the new sheets there (Godot fills in each sheet's .import uid and
# dest_files) and copies the generated files back. Headless, no window, no
# audio. Prints "RIG built <n>/<m>"; exit 1 when any character failed.
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
tool_tmp
USERDIR="evolvemobile_rigs_$$"
tool_clean "$HOME/Library/Application Support/$USERDIR"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' "$USERDIR" > "$TMP/proj/override.cfg"
# The class cache must know RigBuilder before the -s script compiles.
run_godot "$TMP/import1.log" --headless --import --path "$TMP/proj"
run_godot "$TMP/build.log" --headless --path "$TMP/proj" -s res://tools/build_rigs.gd -- "$@"
STATUS=$?
grep -E "^RIG |RIG: |SCRIPT ERROR" "$TMP/build.log"
run_godot "$TMP/import2.log" --headless --import --path "$TMP/proj"
for p in $(grep "^RIG_OUT " "$TMP/build.log" | sed 's|^RIG_OUT res://||'); do
  mkdir -p "$SRC/$(dirname "$p")"
  cp "$TMP/proj/$p" "$SRC/$p"
done
exit $STATUS
