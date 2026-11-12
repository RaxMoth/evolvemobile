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
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
tool_tmp
USERDIR="evolvemobile_trees_$$"
tool_clean "$HOME/Library/Application Support/$USERDIR"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' "$USERDIR" > "$TMP/proj/override.cfg"
# The class cache must know MetaSkillTree / MetaSkillNode before the -s script compiles.
run_godot "$TMP/import.log" --headless --import --path "$TMP/proj"
run_godot "$TMP/build.log" --headless --path "$TMP/proj" -s res://tools/build_skill_trees.gd -- "$@"
STATUS=$?
grep -E "^TREE |TREE: |SCRIPT ERROR" "$TMP/build.log"
for p in $(grep "^TREE_OUT " "$TMP/build.log" | sed 's|^TREE_OUT res://||'); do
  mkdir -p "$SRC/$(dirname "$p")"
  cp "$TMP/proj/$p" "$SRC/$p"
done
exit $STATUS
