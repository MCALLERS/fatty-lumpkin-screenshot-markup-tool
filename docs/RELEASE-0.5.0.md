# Version 0.5.0

This update adds screenshot sessions and gives the iPad app a simpler ivory-and-green appearance with the full **Fatty Lumpkin Screenshot Markup Tool** title.

## What changed

- **Start fresh:** On iPad, choose **Session → New session · Reset count**. The count returns to zero, and new captures start at 1. Previous originals and finished PNGs remain on the Mac.
- **Clear older files:** Choose **Session → Review older files…** to see the screenshot count, file count, and size. Confirming moves previous-session files to the Mac’s Trash while keeping the current session. Restore files from Trash on the Mac if needed; emptying Trash makes deletion permanent.
- **Protect unfinished work:** Finish drawings and wait for the Mac’s clipboard confirmation before changing sessions. Failed reset requests reuse their identifier, and a changed cleanup preview must be reviewed again.
- **Recover drafts:** Unfinished iPad drafts remain available through **Browse → To do**, including after another client starts a session. If a Mac source is missing, the cached draft can still be opened. Swiping its row and confirming **Discard drawing** removes only its unfinished iPad drawing and pending upload.
- **Keep familiar navigation:** This release includes the 0.4.1 searchable screenshot browser, oldest/newest shortcuts, and Previous/Next navigation that preserves unfinished drawings. The Pencil palette stays hidden while browsing or managing sessions.

Install **version 0.5.0 of both the Mac companion and native iPad app** to use session management. The updated iPad app can still capture, browse, and save with an older Mac companion; its Session panel explains when the Mac needs an update.

Cleanup applies to the **Mac screenshot repository**. This release retains local iPad draft caches. Resetting the count does not delete files, and moving older files to Trash does not clear images already copied or shared elsewhere.

## Verification

All **50 automated tests passed**:

- 17 Python companion-protocol tests passed.
- 15 JavaScript input and queue tests passed.
- 18 native iPad simulator tests passed, including session reset and retry, unfinished-draft protection, clipboard acknowledgement, cleanup conflicts, missing-source recovery, and existing navigation regressions.
- The new-session regression failed before the implementation and passed afterward.
- Native iPad portrait and landscape layouts, plus the Session panel, were visually reviewed with synthetic content in the simulator. Secondary text contrast was strengthened after review.
- The iPad build was installed on a physical device over USB. The end-to-end capture, Apple Pencil, save, and clipboard workflow has not been tested on that device in this run.

## Publication status

- **Mac:** Version 0.5.0 is public in [GitHub release v0.5.0-beta.1](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases/tag/v0.5.0-beta.1). The app and DMG were notarized. The downloaded DMG passed SHA-256 verification, stapling validation, Gatekeeper assessment, and the packaged companion-protocol check. The verified downloaded app was installed at `~/Applications/Screenshot Tool.app`; the prior installation was retained in the ignored `work/` directory.
- **iPad:** Version **0.5.0 (13)** was installed over USB, uploaded to App Store Connect, and submitted to the **Public Beta** group. Its status is **Waiting for Review**; build 13 is not yet publicly available. The [public TestFlight invitation](https://testflight.apple.com/join/bFbsKKmV) was verified as accepting testers, with the earlier 0.4.0 build approved.
- **Website:** [screenshot.bombadillo-ai.com](https://screenshot.bombadillo-ai.com) is deployed over HTTPS through the Cloudflare Worker `fatty-lumpkin-screenshot-site`. Live HTML, CSS, JavaScript, privacy content, and illustrations match the local assets. Motion-demo step, play, and replay controls were verified live, along with both Mac 0.5.0 download links and the TestFlight invitation.
