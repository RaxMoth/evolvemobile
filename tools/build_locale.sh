#!/bin/zsh
# Rebuild the imported translations Assets/Locale/strings.<locale>.translation
# from Assets/Locale/strings.csv (the key of a row is its English text; one
# column per language: en, de).
#
#   tools/build_locale.sh           # import the CSV on a temp copy, copy the files back
#   tools/build_locale.sh --check   # exit 1 when the committed files are not what the CSV gives
#
# The editor runs the same import by itself when it sees the changed CSV; this
# is the headless way (the hourly loop, a checkout without an editor) and the
# check before a commit. Works on a temp copy with its own user://
# (override.cfg), never runs Godot on the real project directory (the editor
# may have it open). Headless, no window, no audio. Prints one "LOCALE <file>
# <state>" line per translation file.
SRC="$(cd "$(dirname "$0")/.." && pwd)"
source "$SRC/tools/tool_env.zsh"
tool_tmp
USERDIR="evolvemobile_locale_$$"
tool_clean "$HOME/Library/Application Support/$USERDIR"
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' "$USERDIR" > "$TMP/proj/override.cfg"
# A missing output makes the import run whatever the copied import cache says.
rm -f "$TMP/proj/Assets/Locale/"strings.*.translation
run_godot "$TMP/import.log" --headless --import --path "$TMP/proj"
STATUS=0
FOUND=0
for built in "$TMP/proj/Assets/Locale/"strings.*.translation(N); do
  FOUND=$((FOUND + 1))
  name="$(basename "$built")"
  if cmp -s "$built" "$SRC/Assets/Locale/$name"; then
    echo "LOCALE $name up to date"
  elif [ "$1" = "--check" ]; then
    echo "LOCALE $name STALE (run tools/build_locale.sh)"
    STATUS=1
  else
    cp "$built" "$SRC/Assets/Locale/$name"
    echo "LOCALE $name rebuilt"
  fi
done
if [ "$FOUND" = "0" ]; then
  echo "LOCALE: the import wrote no translation (see strings.csv.import)"
  grep -h "ERROR" "$TMP/import.log" | head -5
  STATUS=1
fi
exit $STATUS
