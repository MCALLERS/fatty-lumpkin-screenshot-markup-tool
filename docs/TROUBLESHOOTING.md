# Troubleshooting

## Connection times out

- Keep the Mac companion running and the Mac awake.
- Put both devices on the same trusted network. A guest network or router’s client isolation can block local connections even when the Wi-Fi names match.
- After changing networks, quit and reopen the Mac app and scan its new QR code. The displayed Mac address should belong to a network reachable from the iPad. Retry alone uses the old address.
- On iPad: **Settings → Privacy & Security → Local Network**; allow the app. For camera permission, use the Camera section there.
- On Mac: **System Settings → Privacy & Security → Local Network**; allow the companion if listed. If the firewall asks, allow incoming connections for this app. Do not disable the firewall.
- If a VPN prevents local access, use its supported local-network setting or consult its documentation.
- Try the Safari companion. If Safari also fails, investigate the Mac/network connection before the native app.

## New screenshot does not appear

Click **Set up screenshot folder** on Mac. Confirm the PNG is in **Documents → Screenshot Tool → Inbox**. Avoid holding Control with ⇧⌘4. Screenshots saved only to the clipboard cannot enter the file queue. Existing HEIC/JPEG images can be converted using **Import an existing image**.

Wait for macOS to finish writing the file. The native app limits images to 16 million pixels to keep PencilKit memory use reasonable; crop an unusually large screenshot. The Mac companion reads at most the 100 newest captures.

## Drawing feels wrong

Use Apple Pencil with **Finger drawing** off to avoid palm marks. In the native app use two fingers to move/zoom, or tap **Fit**. In Safari use the zoom buttons and a finger to pan. The native app and Safari store drafts separately.

## Done appears to stall

The drawing screen can remain visible while the image is being saved or copied. Wait for the completion message. Keep the Mac app running. A timeout does not necessarily mean the save failed; check **Ready** before retrying. Native retries reuse the submission ID to prevent duplicate exports after a lost response.

After the final pending image, the app should return to its welcome screen. Use Previous screenshots to reopen an earlier item.

## Clipboard or shortcut

The newest completed image replaces the previous clipboard content. Paste after the confirmation. For several images or an incompatible agent, use **⌃⌥⌘S** and drag files from Ready. If another app already owns that shortcut, use **Open finished screenshots** in the Mac companion instead.

## Reporting a problem

Open a GitHub issue with app version, macOS/iPadOS versions, the step that failed, and whether Safari behaves the same way. Use a synthetic screenshot. Never post pairing links, QR codes, private screenshots, or files from the app’s private state directory.
