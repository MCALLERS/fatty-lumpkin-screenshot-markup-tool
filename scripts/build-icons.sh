#!/bin/zsh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source="$root/Branding/pony-bookplate.png"
iconset="$root/work/AppIcon.iconset"
mkdir -p "$iconset" "$root/NativeiPad/ScreenshotTool/Assets.xcassets/Pony.imageset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$root/Branding/AppIcon.icns"
sips -z 1024 1024 "$source" --out "$root/NativeiPad/ScreenshotTool/Assets.xcassets/AppIcon.appiconset/Icon.png" >/dev/null
sips -z 512 512 "$source" --out "$root/NativeiPad/ScreenshotTool/Assets.xcassets/Pony.imageset/Pony.png" >/dev/null
cat > "$root/NativeiPad/ScreenshotTool/Assets.xcassets/Pony.imageset/Contents.json" <<'JSON'
{"images":[{"filename":"Pony.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}
JSON
cp "$source" "$root/Companion/pony.png"
