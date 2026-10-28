#!/bin/zsh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/work/icon-module-cache"
xcrun swift -module-cache-path "$root/work/icon-module-cache" "$root/scripts/render-brand-icon.swift" "$root/Branding"
source="$root/Branding/AppIcon-mac-1024.png"
iconset="$root/work/AppIcon.iconset"
mkdir -p "$iconset" "$root/NativeiPad/ScreenshotTool/Assets.xcassets/BrandMark.imageset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$root/Branding/AppIcon.icns"
cp "$root/Branding/AppIcon-1024.png" "$root/NativeiPad/ScreenshotTool/Assets.xcassets/AppIcon.appiconset/Icon.png"
sips -z 512 512 "$root/Branding/AppIcon-1024.png" --out "$root/Branding/BrandMark.png" >/dev/null
cp "$root/Branding/BrandMark.png" "$root/NativeiPad/ScreenshotTool/Assets.xcassets/BrandMark.imageset/BrandMark.png"
cat > "$root/NativeiPad/ScreenshotTool/Assets.xcassets/BrandMark.imageset/Contents.json" <<'JSON'
{"images":[{"filename":"BrandMark.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}
JSON
cp "$root/Branding/BrandMark.png" "$root/Companion/brandmark.png"
