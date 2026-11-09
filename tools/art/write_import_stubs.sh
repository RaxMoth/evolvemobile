#!/bin/sh
# Every SVG under the given folder imports as DPITexture (re-rasterised at the
# canvas oversampling, crisp on 1.5x / 2x / 3x phones). Godot fills in uid,
# path and params on the next --import.
find "$1" -name '*.svg' | while read f; do
  [ -f "$f.import" ] && grep -q 'importer="svg"' "$f.import" && continue
  printf '[remap]\n\nimporter="svg"\ntype="DPITexture"\n' > "$f.import"
done
