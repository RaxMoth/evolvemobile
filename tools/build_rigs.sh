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
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
USERDIR="evolvemobile_rigs_$$"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/$USERDIR"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' "$USERDIR" > "$TMP/proj/override.cfg"
# The class cache must know RigBuilder before the -s script compiles.
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import1.log" 2>&1
"$GODOT" --headless --path "$TMP/proj" -s res://tools/build_rigs.gd -- "$@" > "$TMP/build.log" 2>&1
STATUS=$?
grep -E "^RIG |RIG: |SCRIPT ERROR" "$TMP/build.log"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import2.log" 2>&1
for p in $(grep "^RIG_OUT " "$TMP/build.log" | sed 's|^RIG_OUT res://||'); do
  mkdir -p "$SRC/$(dirname "$p")"
  cp "$TMP/proj/$p" "$SRC/$p"
done
exit $STATUS
