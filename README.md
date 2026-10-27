<p align="center"><img src="Branding/pony-bookplate.png" width="280" alt="A shaggy pony carrying a red pencil, illustrated on parchment"></p>

# Fatty Lumpkin Screenshot Markup Tool

**Capture on your Mac. Draw on your iPad. Paste into your AI agent.**

A small Mac companion and a native PencilKit iPad app that turn screenshots into clear visual feedback. Circle the awkward button, sketch a new layout, or write a note—then tap **Done**. Your marked-up PNG is saved on the Mac and copied to its clipboard.

[Mac downloads](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases) · [Getting started](docs/GETTING-STARTED.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Privacy](docs/PRIVACY.md)

## Availability

The first release is a beta for **Apple silicon Macs running macOS 14 or later**. The native iPad app requires **iPadOS 18 or later** and will be distributed through TestFlight as **Fatty Lumpkin Screenshot Tool**. A public TestFlight invitation will be added here after Apple’s beta review. The Safari companion works with the Mac download in the meantime.

## The everyday loop

1. Open the Mac companion and the iPad app (or your saved Safari page).
2. On Mac, press **⇧⌘4** and select an area.
3. On iPad, annotate with Apple Pencil. Tap **Done** or **Done & Next**.
4. Wait for the confirmation that it was copied on your Mac, then press **⌘V** in Codex, Claude Code, or another app that accepts images.

Capture several screenshots and annotate them in order. Originals stay intact. Finished PNGs collect in **Documents → Screenshot Tool → Ready**. Press **⌃⌥⌘S** on your Mac to open that folder from any app while the companion is running.

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

The code is available under the [MIT license](LICENSE). The pony artwork was generated for this project; see [art direction and prompt](Branding/ART-DIRECTION.md). This is an independent project, with no affiliation with Apple, OpenAI, Anthropic, or any fantasy franchise.
