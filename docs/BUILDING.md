# Building from source

The end-user Mac download includes its runtime. The following tools are for contributors only.

## Mac development build

Requires Apple silicon, macOS 14+, Xcode (or compatible Command Line Tools), and Python 3. The development app uses `/usr/bin/python3` unless a bundled helper is present.

```sh
scripts/build-icons.sh
scripts/build.sh
python3 -m unittest discover -s tests -p 'test_*.py'
node --test tests/input.test.cjs
```

Node is used only for Safari input/queue tests. The Mac binary’s `--self-test` creates a temporary library and a private test pasteboard; it does not touch your screenshots.

## Self-contained signed Mac build

Use a Python version supported by PyInstaller. The first beta was packaged with CPython 3.14.10 (Astral python-build-standalone build 20261026) and PyInstaller 6.22.3. The bundled Python must itself support the minimum advertised macOS version.

```sh
uv python install 3.14.10
uv venv --python 3.14.10 --managed-python --seed work/distribution-venv
work/distribution-venv/bin/python -m pip install 'pyinstaller==6.22.3'
export SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
scripts/package-mac.sh
python3 scripts/verify-packaged-companion.py 'build/Fatty Lumpkin Screenshot Markup Tool.app'
```

Recheck ThirdParty notices when changing the Python installation: PyInstaller bundles native libraries from that installation. The script signs the helper and its dependencies, then the outer app with hardened runtime. See RELEASING.md for notarization. No signing secrets belong in this repository.

## Native iPad app

Requires Xcode with iPadOS 18+ SDK support. Xcode 27 was used for this beta. The project has no package dependencies.

```sh
python3 NativeiPad/generate-project.py
xcodebuild -project NativeiPad/ScreenshotTool.xcodeproj -scheme ScreenshotTool \
  -destination 'platform=iOS Simulator,name=YOUR_INSTALLED_IPAD_SIMULATOR' \
  -derivedDataPath NativeiPad/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Choose an installed iPad simulator name using Xcode or `xcrun simctl list devices available`. For a device build, choose your own Apple development team in Xcode. Forks should use their own bundle identifier; the published identifier is owned by the maintainer. Keep a paired Mac companion running for an end-to-end test.

The generator produces the checked-in project and shared scheme deterministically. Add Swift sources to the appropriate directory, rerun the generator, and commit both source and project changes.
