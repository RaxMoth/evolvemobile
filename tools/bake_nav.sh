#!/bin/zsh
# Re-bake the world navigation mesh after editing World.tscn's Ground tiles:
# writes Scenes/World/world_navigation.tres. Runs on a temp copy (the Godot
# binary may be newer than the project) and copies only that file back.
# (In the editor: select World.tscn's "Navigation" node -> Bake NavigationPolygon.)
set -e
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$HOME/Library/Application Support/evolvemobile_bake"' EXIT
rsync -a --exclude .git --exclude .DS_Store "$SRC/" "$TMP/proj/"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="evolvemobile_bake"\n' > "$TMP/proj/override.cfg"
"$GODOT" --headless --import --path "$TMP/proj" > "$TMP/import.log" 2>&1 || true
"$GODOT" --headless --path "$TMP/proj" -s res://tools/bake_nav.gd > "$TMP/bake.log" 2>&1
grep "^BAKE " "$TMP/bake.log"
if grep -q "SCRIPT ERROR\|bake produced no polygons" "$TMP/bake.log"; then grep -E "SCRIPT ERROR|ERROR" "$TMP/bake.log" | head -5; exit 1; fi
cp "$TMP/proj/Scenes/World/world_navigation.tres" "$SRC/Scenes/World/world_navigation.tres"
echo "wrote Scenes/World/world_navigation.tres"
