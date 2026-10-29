# Native iPad companion

The iPad app is listed as **Ludwig's Annotated Screenshots**. It uses SwiftUI, PencilKit, and VisionKit QR scanning, with no third-party SDKs.

See [build instructions](../docs/BUILDING.md), [setup](../docs/GETTING-STARTED.md), and [architecture](../docs/ARCHITECTURE.md).

The native app and Safari companion share the same local Mac protocol, but keep their pairing credentials and unfinished drafts separately. Saves are full-resolution flattened PNGs, limited to 16 million pixels. Local retry data includes a stable submission ID so a dropped response does not duplicate an export.

## Release status — 28 October 2026

Native iPad **0.5.1 (17)** is **Approved** and available in the existing **Public Beta** TestFlight group. Earlier builds **0.5.1 (14)** and **0.5.0 (13)** are also approved. The full App Store version **1.0** remains **Prepare for Submission**; beta approval is separate from an App Store release.

Build **0.5.1 (17)** passed local validation, upload, and Beta App Review. Existing testers can update in TestFlight; new testers can use the unchanged [public invitation](https://testflight.apple.com/join/bFbsKKmV). Automatic tester notification was enabled. The existing Mac 0.5.1 download supports its PNG handoff without an update.

## Build 17: text and voice notes

Build **0.5.1 (17)** adds **Text / voice** above the screenshot. Choose it, tap a place on the image, and type or use the microphone on the iPad keyboard to dictate. Review the text, choose Small/Medium/Large, and tap **Add note**. Drag the placed note to move it; tap it to edit or delete it. **Draw** returns to Pencil. Undo/redo covers both notes and strokes.

Placed notes stay editable in local drafts and are included in the finished PNG when you tap Done. They survive screenshot navigation, reopening, and queue resets under **Browse → To do**. Old drawing-only drafts remain compatible. This version uses Apple's system Dictation settings; it adds no app microphone permission or paid speech provider. All 44 native simulator tests passed, and the user confirmed a dictated note plus Pencil annotations reached the Mac chat successfully. See [build 17 notes](LOCAL-BUILD-17.md).

## Navigation fix from build 16

Build **0.5.1 (16)** fixes the previous/next arrows after the last pending screenshot is saved. From the welcome screen, left opens the newest saved screenshot and right opens the oldest; ordinary navigation remains chronological without wrapping. All 24 native tests pass. See [local build 16 notes](LOCAL-BUILD-16.md). This is a local development build, not a TestFlight update.

## Artwork and queue controls from build 15

Build **0.5.1 (15)** adds the Ludwig drawing illustration, a quiet margin quotation that changes at launch or after a successful Done, and a visible **Clear queue** button beside Browse. Its confirmation resets the current session to zero without deleting files. Original screenshots and finished PNGs stay on the Mac; unfinished iPad drawings remain available in **Browse → To do**. Clearing waits for saving/loading and clipboard confirmation, and refuses to reset the Mac if the current draft cannot be saved locally.

The quote information button opens the source and context: [Tractatus, Ogden/Ramsey 1922 translation](https://www.wittgensteinproject.org/w/index.php/Tractatus_Logico-Philosophicus_(English)), propositions 2.1, 2.12, and 4.1212. Artwork is bundled locally from the approved Ludwig illustration. It stays outside the drawing canvas.

Build 15 was a local development build separate from **0.5.1 (14)**, which is now approved for Public Beta. Its artwork, quotes, and Clear queue are retained in build 17. See [historical build 15 notes](LOCAL-BUILD-15.md).

## Sessions and storage

With the Mac companion version 0.5.0 or later, tap **Session → New session · Reset count** to start at zero. Previous originals and finished PNGs stay in the Screenshot Tool folders on your Mac. New captures start at 1. Reset requests reuse an identifier when retried, including after an iPad app restart.

To clear previous sessions, tap **Session → Review older files…**. The app shows the screenshot count, file count, and size before asking you to confirm moving them to the Mac’s Trash. Current-session files stay in place. A changed or expired preview requires another review. This release retains local iPad draft caches; the cleanup applies to the Mac repository.

Finish unfinished drawings and wait for the Mac’s clipboard confirmation before managing sessions. **Browse → To do** includes unfinished drafts even if another client started a new session. A locally cached draft can still be opened when its Mac source is missing. Swipe its row and confirm **Discard drawing** if you no longer need it; this removes only that iPad drawing and its pending upload. It does not delete a Mac original or an already finished PNG.

Older Mac companions still support ordinary capture, browsing, and saving. The Session panel explains that an update is needed for reset and cleanup.

Run the ScreenshotTool scheme’s tests on an iPad simulator. The tests cover capture validation, pairing URL validation, queue order, stable browsing, export dimensions and ink, draft recovery, authenticated saves, unauthorized responses, session reset/retry, clipboard protection, cleanup conflicts, and missing-source draft recovery.
