#!/bin/zsh
# Write the skill trees Data/SkillTrees/<tree_id>.tres from
# Scripts/MetaSkills/skill_tree_data_v2.gd (see tools/build_skill_trees.gd).
#
#   tools/build_skill_trees.sh [--force] [tree_id ...]   # no id: all nine trees
#
# A one-off: the .tres files are the trees now (edited in the inspector), so an
# existing file is kept unless --force is given. Works on a temp copy with its
# own user:// (override.cfg), never runs Godot on the real project directory
# (the editor may have it open), and copies the written files back. Headless,
# no window, no audio. Prints "TREE built <n>, kept <k>, of <m>"; exit 1 when
# a tree could not be written.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
USERDIR="evolvemobile_trees_$$"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/$USERDIR"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' "$USERDIR" > "$TMP/proj/override.cfg"
# The class cache must know MetaSkillTree / MetaSkillNode before the -s script compiles.
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1
"$GODOT" --headless --path "$TMP/proj" -s res://tools/build_skill_trees.gd -- "$@" > "$TMP/build.log" 2>&1
STATUS=$?
grep -E "^TREE |TREE: |SCRIPT ERROR" "$TMP/build.log"
for p in $(grep "^TREE_OUT " "$TMP/build.log" | sed 's|^TREE_OUT res://||'); do
  mkdir -p "$SRC/$(dirname "$p")"
  cp "$TMP/proj/$p" "$SRC/$p"
done
exit $STATUS
