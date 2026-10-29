# Version 0.5.1 — Mac release and iPad beta updates

## Current status — 28 October 2026

- **Mac 0.5.1 (14):** published, signed, notarized, stapled, and verified from the public download. The existing Mac download and website are unchanged for the iPad text-note feature.
- **Native iPad 0.5.1 (14):** **Approved** in the existing **Public Beta** TestFlight group. The earlier **0.5.0 (13)** build is also approved.
- **Native iPad 0.5.1 (17):** local build and physical voice-note workflow validated; uploaded successfully to App Store Connect and processing. Public Beta assignment and beta review are not yet complete; tester availability is not confirmed.
- **Full App Store version 1.0:** **Prepare for Submission**. Beta approval does not make this a public App Store release.

## Branding release

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

The development-signed 0.5.1 (14) app was installed successfully on the connected physical iPad as an update to the existing bundle ID. It was subsequently replaced by local builds 15, 16, and 17. The original build 14 verification did not exercise physical-device Pencil capture → Done → Mac paste; the user subsequently confirmed that workflow with a dictated text note and Pencil marks in build 17, described below.

## Distribution

The renamed iPad **0.5.1 (14)** archive was uploaded successfully to the existing App Store Connect app, assigned to the existing **Public Beta** group with explicit user approval, and submitted to Beta App Review. Its original **Waiting for Review** status was superseded by **Approved**, verified on 28 October 2026. The existing English (U.S.) app name and TestFlight description were saved with the new branding.

The Mac app and DMG are Developer ID signed, accepted by Apple notarization, and stapled. The read-only mounted DMG passed signature verification, Gatekeeper assessment, the Mac self-test, and the packaged companion-protocol check. The local DMG and checksum are in `build/Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg` and `build/SHA256SUMS-0.5.1.txt`.

App Store Connect now shows **Ludwig's Annotated Screenshots** on the existing app record. The verified DMG app was installed at `~/Applications/Ludwig's Annotated Screenshots.app` after the old app and helper were confirmed stopped. The installed copy passed deep signature verification, stapler validation, Gatekeeper assessment, and its self-test. It was launched, and its native window, menu, and workflow instructions visibly show the new name. The previous 0.5.0 app is retained at `work/Screenshot-Tool-0.5.0-before-Ludwig.app`. Screenshot folders and pairing state were not moved.

The public Mac download was freshly downloaded and verified against SHA-256 `563cc48d601775babfc11b72369c11d05a701e6d24d2114256171beb9d22a901`. Both the downloaded DMG and its app passed signature and stapled-ticket verification, and Gatekeeper accepted them. The downloaded app passed `--self-test`; its packaged companion passed the protocol tests in an isolated workspace. These checks confirm the published artifact, independently of local build and installation checks. The website verification is recorded below.

## iPad distribution and source boundary

- **0.4.0 (11)** was the earlier public TestFlight build. It retains the older branding and lacks the later browser/session controls.
- **0.5.1 (14)** is the approved renamed Public Beta build. It includes the existing session tools but not the later Ludwig portrait, quotation margin, or prominent Clear queue shortcut.
- **0.5.1 (15)** added the artwork, quotes, and safe Clear queue shortcut as a local development build. Its 21 behavioral native tests passed. See [historical build 15 notes](../NativeiPad/LOCAL-BUILD-15.md).
- **0.5.1 (16)** fixed the previous/next arrows when the welcome screen has no selected capture. Its 24 native tests passed. See [historical build 16 notes](../NativeiPad/LOCAL-BUILD-16.md).
- **0.5.1 (17)** is the current native source and locally installed build. It retains those improvements and adds the text/voice-note editor. See its validation and tester instructions below.

The Mac build script and signed 0.5.1 artifact remain build **14**. The native project generator now produces build **17**, so this repository snapshot is not a reproduction of the approved iPad build 14. Mac publishing and website deployment do not change TestFlight availability.

## iPad build 17: text and voice notes

Build 17 adds editable text cards placed directly on a screenshot. Tap **Text / voice**, tap the image, then type or speak using the iPad keyboard microphone. Review the text, choose Small/Medium/Large, and tap **Add note**. Drag a card to move it or tap it to edit/delete it. **Draw** returns to Pencil; **Done** flattens both text and ink into the normal PNG for the Mac clipboard.

Notes share undo/redo with Pencil and survive navigation and local draft recovery. Existing drawing-only drafts remain compatible. Navigation stops if saving a draft fails. Changed notes invalidate an earlier failed upload's cached result, while an unchanged retry keeps its original submission identity. Original screenshots stay unchanged. There is no app audio recorder, new speech permission, paid transcription service, or automatic double-tap listening. Apple's keyboard Dictation settings and processing apply.

**Validation:** 44 native simulator tests passed, covering note storage/rendering, legacy drafts, overflow rejection, export, navigation/restart recovery, add/edit/move/delete, undo/redo, retry identity, write failure, zoom/pan/rotation alignment, accessibility placement, and keyboard focus. After the final text-size selector adjustment, all five surface tests passed again. Release compatibility checks also passed: **17 Python companion tests** and **15 Safari tests**. The device archive succeeded and version **0.5.1 (17)** was installed over the existing app container. The user then confirmed a real dictated note plus Pencil marks exported and pasted into the Mac chat successfully. Other languages, offline Dictation, and disabled Dictation settings remain outside physical-device validation.

**TestFlight status:** build **0.5.1 (17)** uploaded successfully to App Store Connect and is processing. Public Beta assignment and beta review are not yet complete; tester availability is not confirmed. Once TestFlight offers build 17, update the existing app and verify **Beta 0.5.1 (17)** in its footer. Follow the [voice-note steps](GETTING-STARTED.md#text-and-voice-notes-native-build-051-17), then confirm the finished PNG contains both text and ink. No Mac update is required. The Safari editor is unchanged. [Detailed build notes](../NativeiPad/LOCAL-BUILD-17.md).

## Publication verification — 28 October 2026

The public repository is now [MCALLERS/ludwigs-annotated-screenshots](https://github.com/MCALLERS/ludwigs-annotated-screenshots). Its identity, history, release tag, and release assets were preserved. The old repository and release-page URLs redirect to the new name; the old direct DMG URL returns a redirect to the new asset URL. A fresh download through the new URL has the same verified SHA-256 as the fully tested package.

Cloudflare's automatic build for website commit `5b05664` succeeded after the repository rename. The public landing page and privacy route use the renamed GitHub links. All 33 non-robots static files matched their reviewed local bytes; Cloudflare's managed `robots.txt` adds its own crawler directives and retains the project's original rules and sitemap. Browser inspection confirmed the download/setup panel, enabled character animation, film playback, and sound controls without page-script errors.

Colleagues can start at **https://screenshot.bombadillo-ai.com/** to download Mac 0.5.1 and pair with Safari immediately, or use the separately approved native TestFlight build. No new iPad build was uploaded during that website/Mac publication; build 17's separate distribution status is recorded above.
