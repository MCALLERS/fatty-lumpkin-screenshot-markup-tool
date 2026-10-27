# Privacy policy

Effective 27 October 2026. Applies to Fatty Lumpkin Screenshot Markup Tool, including the iPad app listed as Fatty Lumpkin Screenshot Tool.

## What the app does

The Mac companion reads screenshots from a local folder and transfers selected images to a paired iPad on the local network. The iPad returns a flattened, annotated PNG. The Mac saves it in Ready and writes it to the clipboard. We do not operate an upload server, analytics service, advertising service, or account system for this app.

## Stored on your devices

- **Mac:** originals and annotated images are in Documents/Screenshot Tool. Pairing keys, completion receipts, capture identifiers, and screenshot-settings backups are in Library/Application Support/Screenshot Tool.
- **Native iPad:** pairing credentials are stored in Keychain. Draft drawings, cached screenshots, and pending exports are in the app’s local container, excluded from backup where configured by the app. Keychain entries can persist after app removal, depending on iPadOS behavior.
- **Safari:** pairing cookies and local draft/queue state are stored in Safari website data.
- **Clipboard:** the last completed image and its local file URL are copied on the Mac. System clipboard features and other apps may read or synchronize this content under your device settings.

Files are not automatically deleted from the Mac. Remove them in Finder when you no longer need them. Deleting the iPad app removes its local app data; clear Safari website data to remove browser drafts and pairing. Removing a file from a synced Documents folder also follows your sync provider’s behavior.

## Network and permissions

The Mac and iPad communicate over **unencrypted local HTTP**, authenticated by a pairing key. Use a trusted private network. Authentication is not transport encryption: a party able to observe local traffic may see images or credentials. Do not expose or port-forward the service to the Internet. A QR code/pairing link grants access to the local screenshot library; keep it private.

Camera access is used to scan the Mac’s pairing QR code. Local Network access connects to the Mac. The app does not record or upload camera footage. The Mac may request Documents access to read and save screenshots.

## Third parties

The app does not send screenshots to an AI provider. You choose when and where to paste or upload them. Those services’ policies apply after you share. iCloud Drive or another backup/sync service may independently copy the Documents folder if enabled. Apple may collect TestFlight diagnostics and tester feedback under its own policies. GitHub hosts downloads, source, and public issue reports under its policies.

## Contact

For general privacy questions, open an issue at https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/issues without including private images or connection keys. For a security vulnerability, use the repository’s private vulnerability reporting feature.
