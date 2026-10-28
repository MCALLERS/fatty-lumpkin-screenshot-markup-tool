<p align="center"><img src="Branding/BrandMark.png" width="280" alt="Screenshot corners, an annotation, and a pencil"></p>

# Ludwig's Annotated Screenshots

**Capture on your Mac. Draw on your iPad. Paste into your AI agent.**

A small Mac companion and a native PencilKit iPad app that turn screenshots into clear visual feedback. Circle the awkward button, sketch a new layout, or write a note—then tap **Done**. Your marked-up PNG is saved on the Mac and copied to its clipboard.

[Website](https://screenshot.bombadillo-ai.com) · [iPad TestFlight](https://testflight.apple.com/join/bFbsKKmV) · [Mac downloads](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases) · [Getting started](docs/GETTING-STARTED.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Privacy](docs/PRIVACY.md)

## Availability

Start at the [website](https://screenshot.bombadillo-ai.com) for the workflow, Mac download, and iPad invitation. The Mac companion requires **Apple silicon and macOS 14 or later**; the native iPad app requires **iPadOS 18 or later**. Safari is included with the Mac companion and can be used immediately without TestFlight.

| Component | Current status |
| --- | --- |
| Mac 0.5.1 (14) | Renamed, signed, notarized, and ready to publish as `v0.5.1-beta.1`; public download and website update verification pending. |
| Native iPad 0.4.0 (11) | Approved public TestFlight build, still showing the earlier Fatty Lumpkin branding. |
| Native iPad 0.5.1 (14) | Renamed build assigned to Public Beta; **Waiting for Review**. |
| Native iPad 0.5.1 (15) | Current repository source and local device build, including Ludwig artwork, quotes, and Clear queue; not uploaded to TestFlight. |

The prepared Mac asset is `Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg`. Until its publication is verified, the earlier Mac 0.5.0 release remains the public download. See [sharing the beta](docs/SHARING-BETA.md) and the [upgrade note](docs/GETTING-STARTED.md#updating-from-fatty-lumpkin).

## The everyday loop

1. Open the Mac companion and the iPad app (or your saved Safari page).
2. On Mac, press **⇧⌘4** and select an area.
3. On iPad, annotate with Apple Pencil. Tap **Done** or **Done & Next**.
4. Wait for the confirmation that it was copied on your Mac, then press **⌘V** in Codex, Claude Code, or another app that accepts images.

Capture several screenshots and annotate them in order. Use **Session** on iPad to reset the count for a new task, then optionally move previous-session screenshots to the Mac’s Trash after reviewing the file count. Both apps need version 0.5.0 or later for session controls; the currently approved native iPad 0.4.0 build does not include them. Originals stay intact until you choose cleanup. Finished PNGs collect in **Documents → Screenshot Tool → Ready**. Press **⌃⌥⌘S** on your Mac to open that folder from any app while the companion is running.

The native app uses PencilKit for Pencil strokes, undo/redo, pan and zoom, and local draft recovery. The Safari version remains included as an alternative. Pairing is remembered; both devices must remain on the same trusted local network. A changed Mac IP address requires reopening the Mac companion and scanning its new QR code.

## First-time setup

Install the Mac app from the release DMG. Open it and click **Set up screenshot folder**. On iPad, open the native app and scan the Mac’s **Connect iPad** QR code. For Safari, scan with the iPad Camera app, then use **Share → Add to Home Screen**. See the [illustrated setup guide](docs/GETTING-STARTED.md) for permissions and returning after a restart.

## Local by design

There is no app account, analytics SDK, cloud relay, or AI service integration. The Mac serves files directly to your paired iPad over local HTTP. **Local HTTP is not encrypted; use a trusted private network.** Pasting an image into another service shares it under that service’s policies. macOS may independently sync Documents through iCloud if you enabled it. [Privacy and storage details](docs/PRIVACY.md).

## Build, learn, contribute

- [Build from source](docs/BUILDING.md)
- [Architecture and protocol](docs/ARCHITECTURE.md)
- [Release procedure](docs/RELEASING.md)
- [Agent workflow skill](skills/screenshot-feedback/SKILL.md)
- [Contributing](CONTRIBUTING.md) · [Security](SECURITY.md)

The repository includes native iPad source for local build 15, beyond the separate build 14 archive submitted to Apple. See [local build 15 notes](NativeiPad/LOCAL-BUILD-15.md); publishing this source does not publish that iPad build to TestFlight.

The code is available under the [MIT license](LICENSE). The screenshot-and-pencil icon is an original vector mark; see [brand assets and provenance](Branding/ART-DIRECTION.md). This is an independent project, with no affiliation with Apple, OpenAI, Anthropic, or any fantasy franchise.
