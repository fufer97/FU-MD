#!/bin/bash
# Assets/icon_1024.png → AppIcon.icns（仅依赖系统 sips/iconutil）
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Assets/icon_1024.png"
ICONSET="Assets/AppIcon.iconset"
[ -f "$SRC" ] || { echo "缺少 $SRC"; exit 1; }

/bin/rm -rf "$ICONSET" "Assets/AppIcon.icns"
mkdir -p "$ICONSET"

for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" \
            "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
  size=${spec%% *}
  name=${spec#* }
  sips -z "$size" "$size" "$SRC" --out "$ICONSET/$name.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "Assets/AppIcon.icns"
/bin/rm -rf "$ICONSET"
echo "✅ Assets/AppIcon.icns"
