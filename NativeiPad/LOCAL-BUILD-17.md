# iPad build 0.5.1 (17) — text and voice notes

This build adds editable screenshot text notes with Apple's keyboard Dictation. It retains build 16's previous/next fix and build 15's artwork, quotations, and Clear queue. It is installed and tested locally; the published Mac download is unchanged. Website release and privacy instructions were deployed from commit `d28ef26`; both public pages matched the reviewed source bytes on 28 October 2026.

## Distribution status — 28 October 2026

Build **0.5.1 (17)** is **Approved** and available in the existing **Public Beta** TestFlight group. The verified iOS Builds row shows **Approved / Public Beta**, with no pending **Notify Testers** action. Automatic tester notification was enabled when it was submitted. The [public invitation](https://testflight.apple.com/join/bFbsKKmV) is unchanged. The full App Store version **1.0** remains **Prepare for Submission**; TestFlight distribution and App Store release are separate steps.

The beta description, review notes, and What to Test instructions were saved with the voice-note steps and renamed website/GitHub links. Earlier build **0.5.1 (14)** remains approved.

No new Mac binary is required for text notes: the iPad sends a normal flattened PNG through the existing save and clipboard path. Safari does not yet have the text-note editor.

## Try it

1. Open a screenshot and select **Text / voice**.
2. Tap the place where the note should sit.
3. Tap the microphone on the iPad keyboard and speak, or type in the editor. Review the text and choose Small, Medium, or Large.
4. Tap **Add note**. Drag the note to move it; tap to edit it. Deleting a note asks for confirmation and can be undone.
5. Tap **Draw** to return to Pencil. **Done** includes both notes and Pencil marks in the normal PNG/clipboard flow.

If the keyboard microphone is unavailable, check **Settings → General → Keyboard → Enable Dictation**. Availability depends on the device's language, keyboard, and settings. This version uses the system's Dictation control; it does not start recording automatically or provide a separate in-app recorder. A dedicated microphone action and gesture shortcut remain in [the backlog](../docs/BACKLOG.md).

## Persistence and interaction

- Notes store their text, identity, position, width, and font size in source-image coordinates. They share the screenshot's zoom/pan transform. A shared renderer draws the screen card and finished PNG, with overflow checks instead of silent truncation.
- Placed notes survive navigation, restart, failed-upload retries, and queue clearing; unfinished notes remain under Browse → To do. Old drafts decode with an empty note list. Original screenshots stay unchanged.
- Notes and Pencil strokes use the canvas's undo history. Notes can also be edited and moved with accessibility actions. In Draw mode, notes do not intercept Pencil strokes.
- The composer releases Pencil focus and blocks navigation, saving, pairing, and session changes while open. Cancel leaves the screenshot content unchanged. Use Add/Save note to persist the editor's text; an unplaced composer buffer is not a saved note.
- Navigation and pairing stop if the existing draft cannot be saved locally, preserving the in-memory annotations for recovery.
- Editing invalidates a failed upload's submission identity, so its old PNG is never reused. An unchanged retry uses the same identity and bytes.
- No speech SDK, paid service, new app microphone permission, or app audio recording was added. Apple's Dictation settings and processing apply; offline speech is not promised for every device/language. See [privacy](../docs/PRIVACY.md#optional-keyboard-dictation).

## Verification

- **44 native simulator tests passed**: the existing 24 plus 6 note rendering/storage tests, 9 workflow tests, and 5 surface/focus/preview tests.
- After the final text-size selector adjustment, the 5 surface tests passed again. Synthetic workspace and composer attachments were exported and inspected.
- Release compatibility checks also passed: **17 Python companion tests** and **15 Safari tests**.
- Coverage includes text-only drafts, legacy decoding, original preservation, full-resolution export, add/edit/move/delete with undo/redo, cancelled/stale callbacks, write failure and recovery, upload identity/PNG changes, zoom/pan/rotation alignment, drawing hit testing, accessible placement, and keyboard-focus preservation.
- Initial test runs caught two overly strict test comparisons: PencilKit serialization bytes can change after decoding, and transformed CGRect values have floating-point rounding. Assertions now compare rendered ink plus stroke semantics, and coordinates within a subpixel tolerance.

Private local evidence: `work/text-notes-final-17.xcresult` and `.log` (44 tests), `work/text-notes-composer-17.xcresult` and `.log` (final 5 surface tests), and `work/text-notes-composer-preview-17/` (synthetic PNGs).

The App Store Connect export/upload succeeded (`EXPORT SUCCEEDED`). After processing, build **0.5.1 (17)** was assigned to **Public Beta**, submitted for review, and verified **Approved**.

The Apple Development archive succeeded at `build/Ludwig-0.5.1-17.xcarchive` and was installed over the prior development build on the connected iPad, using the same bundle identifier and app container. Installation metadata is in `work/ludwig-ipad-installed-17.json`.

**Physical workflow confirmed:** on 28 October 2026, the user dictated a note, added Pencil annotations, and pasted the finished image from the Mac into the chat. The supplied screenshot showed both the note and the marks, and the user reported that it worked well.

The wider Dictation matrix—other languages, offline availability, and disabled Dictation settings—has not been verified on physical devices. Simulator tests validate editable notes and export, not speech-recognition accuracy. No pairing keys, clipboard contents, or microphone audio were inspected during development.

## Tester check for build 17

Update the existing app in TestFlight and verify **Beta 0.5.1 (17)** in its footer. Keep the existing Mac companion running. Try the five steps above, then press **Command–V** in a Mac chat or another app that accepts images. Confirm that both the text and Pencil marks arrive. Revisit the screenshot with Browse to check that its note remains editable. If reporting an issue, include the build number, what you tapped, and what happened; do not include pairing QR codes or private screenshots.
