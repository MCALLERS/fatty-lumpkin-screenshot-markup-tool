# Share the beta with colleagues

Start at [Ludwig's Annotated Screenshots](https://screenshot.bombadillo-ai.com). Use that website as the front door for the workflow, Mac download, and iPad invitation.

**Publication status — 28 October 2026:** the renamed Mac **0.5.1 (14)** package is published as [`v0.5.1-beta.1`](https://github.com/MCALLERS/ludwigs-annotated-screenshots/releases/tag/v0.5.1-beta.1). A fresh public download passed checksum, signature, notarization-ticket, Gatekeeper, and packaged-runtime verification. The website is the front door configured for Mac 0.5.1; the latest Ludwig deployment succeeded and the public page matched the prepared source. Native iPad **0.5.1 (14)** is **Approved** in Public Beta. Build **0.5.1 (17)** uploaded successfully and is processing at Apple; it is not yet assigned to Public Beta, and tester availability is not confirmed. The full App Store version **1.0** remains **Prepare for Submission**.

## 1. Install the Mac companion

1. Follow **Download for Mac** on the [website](https://screenshot.bombadillo-ai.com), or open [Mac beta 0.5.1](https://github.com/MCALLERS/ludwigs-annotated-screenshots/releases/tag/v0.5.1-beta.1) directly. Download `Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg`.
2. Open the DMG and drag **Ludwig's Annotated Screenshots.app** into **Applications**. When upgrading, quit the old companion first and keep only one copy running. Earlier downloads use the Fatty Lumpkin name.
3. Open the app and click **Set up screenshot folder** if it appears. Allow Documents and Local Network access if asked. Keep the app running while you annotate.

Requires an **Apple silicon Mac running macOS 14 or later**. The freshly downloaded public 0.5.1 app and DMG passed signature, notarization-ticket, Gatekeeper, and packaged-runtime checks. Apple supports this [Developer ID distribution outside the Mac App Store](https://developer.apple.com/developer-id/).

## 2. Connect your iPad

**Safari works immediately:** on Mac, click **Connect iPad**. Scan its QR code with the iPad **Camera** app and open the link in Safari. Optionally use **Share → Add to Home Screen**. This route does not require TestFlight. It supports drawing but does not yet have the text/voice-note editor.

**Native app:** on an iPad running **iPadOS 18 or later**, install TestFlight, then open the [public beta invitation](https://testflight.apple.com/join/bFbsKKmV). Tap **Accept**, then **Install**. The renamed **0.5.1 (14)** build is approved in Public Beta. In the app, choose **Connect your Mac → Scan Mac QR code**, then scan the Mac’s **Connect iPad** QR code. Allow Camera and Local Network access. Existing testers can use **Update** in TestFlight when a newer build is offered; their app identity and saved pairing remain the same.

Both devices must be on the **same trusted private network**. Guest networks may block pairing. Transfers use authenticated, unencrypted local HTTP. Do not share the pairing QR code.

## 3. Capture, draw, and paste

On Mac, press **Shift–Command–4** and capture an area. Draw on the screenshot on iPad, then tap **Done**. Wait for **Copied on your Mac**, paste into your chosen chat with **Command–V**, and send when ready. Finished PNGs also appear in **Documents → Screenshot Tool → Ready**.

## Which version will colleagues receive?

| Component | Build | Availability |
| --- | --- | --- |
| Renamed Mac app and Safari companion | 0.5.1 (14) | Published as `v0.5.1-beta.1`; fresh public download verified. |
| Renamed native iPad app | 0.5.1 (14) | **Approved** in the existing Public Beta TestFlight group. |
| Native iPad text/voice notes, navigation fix, artwork, quotes, and Clear queue shortcut | 0.5.1 (17) | Uploaded and processing at Apple; not yet assigned to Public Beta. Tester availability is not confirmed. |

Approved iPad build 14 supports the core capture, Pencil, and paste workflow, searchable browsing, and session management with the current Mac companion. Build 17 adds text/voice notes, fixes the navigation arrows on the welcome screen, and includes the artwork, quotations, and **Clear queue** shortcut introduced in local build 15. The earlier **0.5.0 (13)** build is also approved; testers should use the latest build offered in TestFlight.

The user confirmed a physical build 17 test: keyboard Dictation plus Pencil marks → Done → Mac paste. All 44 native simulator tests passed, followed by the final five surface tests; release compatibility checks passed all 17 Python companion and 15 Safari tests. Build, installation, and package checks are documented in the [release notes](RELEASE-0.5.1.md).

When build 17 is offered, update in TestFlight and look for **Beta 0.5.1 (17)** in the app footer. Open a screenshot, tap **Text / voice**, tap a position, and use the keyboard microphone or type. Review and add the note, then use **Draw** for Pencil and **Done** to send both together. The existing Mac 0.5.1 download supports this feature; no new Mac install is needed. See [the full steps](GETTING-STARTED.md#text-and-voice-notes-native-build-051-17).

[Apple’s TestFlight guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) explains public invitations and build approval. TestFlight builds expire, so use the invitation to obtain available updates.
