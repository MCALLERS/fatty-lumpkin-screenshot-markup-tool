#!/bin/zsh
# Build an Apple silicon app including its Python runtime. Notarization is separate.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
python="${BUILD_PYTHON:-$root/work/distribution-venv/bin/python}"
app="$root/build/Fatty Lumpkin Screenshot Markup Tool.app"
"$python" -m PyInstaller --noconfirm --clean --onedir --windowed --name FattyLumpkinCompanion \
  --codesign-identity "$SIGN_IDENTITY" --distpath work/frozen --workpath work/pyinstaller --specpath work Companion/server.py
scripts/build-icons.sh
scripts/build.sh
mkdir -p "$app/Contents/Helpers"
# ditto preserves framework and dylib symlinks.
ditto work/frozen/FattyLumpkinCompanion.app "$app/Contents/Helpers/FattyLumpkinCompanion.app"
ditto ThirdParty "$app/Contents/Resources/ThirdParty"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
"$app/Contents/MacOS/ScreenshotTool" --self-test
printf 'Signed app: %s\n' "$app"
