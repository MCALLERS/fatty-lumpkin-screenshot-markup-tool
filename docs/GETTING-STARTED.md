# Getting started

<img src="../Branding/pony-bookplate.png" width="200" alt="Fatty Lumpkin pony">

## Install on your Mac

1. Download the Apple silicon DMG from [Releases](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases).
2. Open it and drag **Fatty Lumpkin Screenshot Markup Tool.app** to **Applications**.
3. Open the app from Applications. Keep it running while you annotate.
4. Click **Set up screenshot folder** if it appears. This changes macOS screenshots to PNG and saves them in **Documents → Screenshot Tool → Inbox**. It preserves the previous location, format, and HDR settings for restoration from the menu-bar app menu.
5. Allow access to Documents and the local network if macOS asks. No Accessibility or Screen Recording permission is needed: macOS’s own screenshot shortcut performs the capture.

## Connect your iPad

Use the same trusted local network on both devices. Guest networks often prevent devices from communicating.

**Native app:** install the TestFlight beta when an invitation is available. Open **Fatty Lumpkin Screenshot Tool**, tap **Connect your Mac**, then **Scan Mac QR code**. On Mac, click **Connect iPad**. Scan that QR code from inside the iPad app. Allow Camera and Local Network access.

**Safari alternative:** scan the Mac QR code with the iPad Camera app and open the link in Safari. Use **Share → Add to Home Screen** to save a shortcut. You can bookmark the paired page too.

The native app remembers its pairing in Keychain. Safari remembers it in its own website storage. Pair them separately if you use both. Do not share a pairing QR code; it contains your local connection key.

## Capture → mark up → paste

1. **Mac:** press **Shift–Command–4**, then drag a rectangle around the area you want to capture. Do not hold Control; that sends the capture to the clipboard instead of a file.
2. **iPad:** the screenshot appears automatically. Draw with Pencil. In the native app, use two fingers to pan and zoom. Turn on **Finger drawing** if you want to draw without Pencil.
3. **iPad:** tap **Done**. Wait for **Copied on your Mac** before pasting. The page/app stays open, ready for the next capture.
4. **Mac:** click your agent’s message field and press **Command–V**. Add a short instruction and send when ready.

If an agent does not accept image paste, drag the PNG from Finder or use **Copy file path** in the Mac app.

## Several screenshots

Take screenshots consecutively. The iPad queues unfinished captures in chronological order. **Done & Next** saves the current annotation and opens the next one. At the end, the iPad clears to the welcome screen. Use **Previous screenshots** to revisit a saved item.

The clipboard contains the most recently completed image. For the whole batch, press **Control–Option–Command–S** on Mac, select the finished PNGs in Finder, then drag them into your agent. Clipboard support for multiple files varies by agent.

## Where everything lives

In Finder’s sidebar, choose **Documents**, then **Screenshot Tool**:

| Folder | Contents |
| --- | --- |
| Inbox | Original PNG screenshots |
| Ready | Finished annotations, as separate PNG files |
| Annotated | Working copies retained for compatibility with early previews |

The Mac app also has **Open finished screenshots** and **Open all screenshot folders** buttons. The original folder name stays stable across the branding update.

## After switching everything off

Open the Mac app from **Applications**, then open the iPad app. Normally it reconnects automatically. No USB cable or new scan is needed when the Mac address is unchanged. Keep the Mac awake while working.

If you changed Wi-Fi or the Mac’s IP address changed, quit and reopen the Mac app, click **Connect iPad**, and scan the new code in the iPad app. **Retry** keeps using the old address; use **Scan Mac QR code** for the new one.

## Stop using the workflow

In the Mac menu-bar app menu, choose **Restore previous screenshot settings** before quitting. If no backup exists, use **Shift–Command–5 → Options → Save to** to choose your preferred location. Your images remain in Documents until you remove them yourself.
