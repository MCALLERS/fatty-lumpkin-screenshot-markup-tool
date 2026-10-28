#!/bin/zsh
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/build/Ludwig's Annotated Screenshots.app"
# This is generated output: do not retain a frozen helper from an older build.
if [[ -d "$app_dir" ]]; then rm -rf "$app_dir"; fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/Companion"
for resource in server.py index.html app.js style.css; do
  cp "$project_dir/Companion/$resource" "$app_dir/Contents/Resources/Companion/"
done
cp "$project_dir/Branding/BrandMark.png" "$app_dir/Contents/Resources/BrandMark.png"
cp "$project_dir/Branding/BrandMark.png" "$app_dir/Contents/Resources/Companion/brandmark.png"
cp "$project_dir/Branding/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
xcrun swiftc -parse-as-library -O -target arm64-apple-macos14.0 -framework SwiftUI -framework AppKit -framework ImageIO -framework UniformTypeIdentifiers -framework Carbon "$project_dir"/Sources/*.swift -o "$app_dir/Contents/MacOS/ScreenshotTool"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ScreenshotTool</string>
<key>CFBundleIdentifier</key><string>local.mcallers.screenshot-tool</string>
<key>CFBundleName</key><string>Ludwig's Annotated Screenshots</string>
<key>CFBundleDisplayName</key><string>Ludwig's Annotated Screenshots</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>14</string>
<key>CFBundleShortVersionString</key><string>0.5.1</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSLocalNetworkUsageDescription</key><string>Connect to your iPad on your local network so you can annotate screenshots with Apple Pencil.</string>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
"$app_dir/Contents/MacOS/ScreenshotTool" --self-test
printf 'Built: %s\n' "$app_dir"
