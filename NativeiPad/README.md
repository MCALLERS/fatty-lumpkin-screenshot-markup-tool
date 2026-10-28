# Native iPad companion

The iPad app is listed as **Fatty Lumpkin Screenshot Tool**. It uses SwiftUI, PencilKit, and VisionKit QR scanning, with no third-party SDKs.

See [build instructions](../docs/BUILDING.md), [setup](../docs/GETTING-STARTED.md), and [architecture](../docs/ARCHITECTURE.md).

The native app and Safari companion share the same local Mac protocol, but keep their pairing credentials and unfinished drafts separately. Saves are full-resolution flattened PNGs, limited to 16 million pixels. Local retry data includes a stable submission ID so a dropped response does not duplicate an export.

## Sessions and storage

With the Mac companion version 0.5.0 or later, tap **Session → New session · Reset count** to start at zero. Previous originals and finished PNGs stay in the Screenshot Tool folders on your Mac. New captures start at 1. Reset requests reuse an identifier when retried, including after an iPad app restart.

To clear previous sessions, tap **Session → Review older files…**. The app shows the screenshot count, file count, and size before asking you to confirm moving them to the Mac’s Trash. Current-session files stay in place. A changed or expired preview requires another review. This release retains local iPad draft caches; the cleanup applies to the Mac repository.

Finish unfinished drawings and wait for the Mac’s clipboard confirmation before managing sessions. **Browse → To do** includes unfinished drafts even if another client started a new session. A locally cached draft can still be opened when its Mac source is missing. Swipe its row and confirm **Discard drawing** if you no longer need it; this removes only that iPad drawing and its pending upload. It does not delete a Mac original or an already finished PNG.

Older Mac companions still support ordinary capture, browsing, and saving. The Session panel explains that an update is needed for reset and cleanup.

Run the ScreenshotTool scheme’s tests on an iPad simulator. The tests cover capture validation, pairing URL validation, queue order, stable browsing, export dimensions and ink, draft recovery, authenticated saves, unauthorized responses, session reset/retry, clipboard protection, cleanup conflicts, and missing-source draft recovery.
