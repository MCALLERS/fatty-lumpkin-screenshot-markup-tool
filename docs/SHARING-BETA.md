# Share the beta with colleagues

Start at [Ludwig's Annotated Screenshots](https://screenshot.bombadillo-ai.com). Use that website as the front door for the workflow, Mac download, and iPad invitation.

**Publication status — 28 October 2026:** the renamed Mac **0.5.1 (14)** package is published as [`v0.5.1-beta.1`](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases/tag/v0.5.1-beta.1). A fresh public download passed checksum, signature, notarization-ticket, Gatekeeper, and packaged-runtime verification. The website is the front door configured for Mac 0.5.1; its latest deployment is not yet verified. Apple is separately reviewing iPad build 14.

## 1. Install the Mac companion

1. Follow **Download for Mac** on the [website](https://screenshot.bombadillo-ai.com), or open [Mac beta 0.5.1](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases/tag/v0.5.1-beta.1) directly. Download `Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg`.
2. Open the DMG and drag **Ludwig's Annotated Screenshots.app** into **Applications**. When upgrading, quit the old companion first and keep only one copy running. Earlier downloads use the Fatty Lumpkin name.
3. Open the app and click **Set up screenshot folder** if it appears. Allow Documents and Local Network access if asked. Keep the app running while you annotate.

Requires an **Apple silicon Mac running macOS 14 or later**. The freshly downloaded public 0.5.1 app and DMG passed signature, notarization-ticket, Gatekeeper, and packaged-runtime checks. Apple supports this [Developer ID distribution outside the Mac App Store](https://developer.apple.com/developer-id/).

## 2. Connect your iPad

**Safari works immediately:** on Mac, click **Connect iPad**. Scan its QR code with the iPad **Camera** app and open the link in Safari. Optionally use **Share → Add to Home Screen**. This route does not require TestFlight or approval of the pending iPad build.

**Native app:** on an iPad running **iPadOS 18 or later**, install TestFlight, then open the [public beta invitation](https://testflight.apple.com/join/bFbsKKmV). Tap **Accept**, then **Install**. The invitation is named **Ludwig's Annotated Screenshots**, while the currently approved **0.4.0 (11)** app still uses the earlier Fatty Lumpkin branding. In the app, choose **Connect your Mac → Scan Mac QR code**, then scan the Mac’s **Connect iPad** QR code. Allow Camera and Local Network access.

Both devices must be on the **same trusted private network**. Guest networks may block pairing. Transfers use authenticated, unencrypted local HTTP. Do not share the pairing QR code.

## 3. Capture, draw, and paste

On Mac, press **Shift–Command–4** and capture an area. Draw on the screenshot on iPad, then tap **Done**. Wait for **Copied on your Mac**, paste into your chosen chat with **Command–V**, and send when ready. Finished PNGs also appear in **Documents → Screenshot Tool → Ready**.

## Which version will colleagues receive?

| Component | Build | Availability |
| --- | --- | --- |
| Renamed Mac app and Safari companion | 0.5.1 (14) | Published as `v0.5.1-beta.1`; fresh public download verified. |
| Native iPad public beta | 0.4.0 (11) | Approved and available in the existing Public Beta TestFlight group, with older branding. |
| Renamed native iPad app | 0.5.1 (14) | Assigned to Public Beta and **Waiting for Review**; not available to external testers yet. |
| Native iPad artwork, quotes, and Clear queue shortcut | 0.5.1 (15) | Current repository source and a local device build only; not uploaded to TestFlight. |

The approved iPad build supports the core capture, Pencil, and paste workflow. The searchable browser requires native iPad 0.4.1 or later, and session management requires 0.5.0 or later on both devices. The prominent **Clear queue** shortcut and Ludwig quotations belong to local build 15.

The physical Pencil → Done → Mac paste workflow has not been retested for the renamed 0.5.1 release. Build, automated, installation, and package checks are documented in the [release notes](RELEASE-0.5.1.md).

[Apple’s TestFlight guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers) explains public invitations and build approval. TestFlight builds expire, so use the invitation to obtain available updates.
