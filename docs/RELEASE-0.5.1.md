# Version 0.5.1 — Mac release and submitted iPad build 14

Fatty Lumpkin is now **Ludwig's Annotated Screenshots**. The Mac app, native iPad app, Safari companion, menus, pairing instructions, and icons use the new name and the approved screenshot-and-pencil mark.

The Mac release is published at [GitHub tag **`v0.5.1-beta.1`**](https://github.com/MCALLERS/ludwigs-annotated-screenshots/releases/tag/v0.5.1-beta.1), with asset **`Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg`**. A fresh public download has been fully verified. The [website](https://screenshot.bombadillo-ai.com) is the front door configured for Mac 0.5.1; the Ludwig website deployment succeeded and its public page matched the prepared source on 28 October 2026.

This is a branding release. The Mac and iPad bundle identifiers, screenshot library, app state, Keychain pairing service, drafts, and transfer protocol remain unchanged. The internal Mac helper executable retains its original name, and `/pony.png` remains an alias for the new mark so cached companion pages continue to load it.

## Upgrade

Quit the old Mac companion before opening the new app. The app bundle is now **Ludwig's Annotated Screenshots.app**; do not run both names at once. Your `Documents/Screenshot Tool` folders and pairing settings remain in place. Update the existing iPad app through TestFlight rather than installing a separate app record.

## Verification

- All 50 automated regression tests passed: 17 Python companion tests, 15 Safari input/queue tests, and 18 native iPad simulator tests.
- The Mac self-test passed: originals preserved, fresh PNG export, dimensions, private clipboard representations, invalid-image handling, and stable working copy.
- The self-contained Developer ID-signed Mac package passed its isolated runtime/protocol check, including branded assets, authentication, save/retry, session reset/retry, cleanup/retry, and synthetic Trash recovery.
- All three packaged Mach-O binaries use bundled or system dependencies and support macOS 14 or earlier.
- The iPad Release archive succeeded with version 0.5.1, build 14, the existing bundle ID, and the existing Apple development team.
- The generated Xcode project is deterministic. The iPad icon is 1024×1024 without alpha; the Mac icon retains rounded transparent corners.

The development-signed 0.5.1 (14) app was installed successfully on the connected physical iPad as an update to the existing bundle ID. It was subsequently replaced locally by development build 15, described separately below. Physical-device Pencil capture → Done → Mac paste has not been exercised for this release. Automated validation does not substitute for that check.

## Distribution

The renamed iPad **0.5.1 (14)** archive was uploaded successfully to the existing App Store Connect app, assigned to the existing **Public Beta** group with explicit user approval, and submitted to Beta App Review. App Store Connect now reports **Waiting for Review**. The existing English (U.S.) app name and TestFlight description were saved with the new branding. Build 14 has not yet been approved for external beta testing.

The Mac app and DMG are Developer ID signed, accepted by Apple notarization, and stapled. The read-only mounted DMG passed signature verification, Gatekeeper assessment, the Mac self-test, and the packaged companion-protocol check. The local DMG and checksum are in `build/Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg` and `build/SHA256SUMS-0.5.1.txt`.

App Store Connect now shows **Ludwig's Annotated Screenshots** on the existing app record. The verified DMG app was installed at `~/Applications/Ludwig's Annotated Screenshots.app` after the old app and helper were confirmed stopped. The installed copy passed deep signature verification, stapler validation, Gatekeeper assessment, and its self-test. It was launched, and its native window, menu, and workflow instructions visibly show the new name. The previous 0.5.0 app is retained at `work/Screenshot-Tool-0.5.0-before-Ludwig.app`. Screenshot folders and pairing state were not moved.

The public Mac download was freshly downloaded and verified against SHA-256 `563cc48d601775babfc11b72369c11d05a701e6d24d2114256171beb9d22a901`. Both the downloaded DMG and its app passed signature and stapled-ticket verification, and Gatekeeper accepted them. The downloaded app passed `--self-test`; its packaged companion passed the protocol tests in an isolated workspace. These checks confirm the published artifact, independently of local build and installation checks. The latest website deployment has not yet been verified.

## iPad distribution and source boundary

- **0.4.0 (11)** remains the approved public TestFlight build. Its installed app retains the older branding and lacks the later browser/session controls.
- **0.5.1 (14)** is the renamed archive submitted to Apple and Waiting for Review. It includes the existing session tools but not the later Ludwig portrait, quotation margin, or prominent Clear queue shortcut.
- **0.5.1 (15)** is the current native iPad repository source and locally installed development build. It adds that artwork, quotes, and safe Clear queue shortcut. Its 21 behavioral native tests passed; it has not been uploaded or submitted to Apple. See [local build 15 notes](../NativeiPad/LOCAL-BUILD-15.md).

The Mac build script and signed 0.5.1 artifact remain build **14**. The native project generator now produces build **15**, so this repository snapshot is not a reproduction of the submitted iPad build 14. Mac publishing and website deployment do not change TestFlight availability.
