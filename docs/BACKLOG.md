# Product backlog

Track product improvements here. Local development builds are distinguished from public releases; future items are not scheduled release commitments.

## VTA-01 — Speak a text note onto a screenshot

**Status:** MVP implemented and locally validated in native iPad build **0.5.1 (17)**. All 44 simulator tests passed, and the user confirmed actual Dictation plus Pencil marks reached the Mac chat. It was uploaded successfully to App Store Connect and is processing. Public Beta assignment and beta review are not yet complete; tester availability is not confirmed. Details are in [the build notes](../NativeiPad/LOCAL-BUILD-17.md). Direct in-app recording and gesture shortcuts remain future work. Updated 28 October 2026.

**Goal:** Point to part of a screenshot, speak feedback, correct the transcript, and leave a movable text annotation that appears in the exported PNG alongside Pencil drawings. Examples: “Make this heading bigger” or “A-minus: clean layout, but the blue is too dark.”

### Recommended interaction

1. Select **Text / voice**, then tap the intended position on the screenshot.
2. Open a standard editable text composer. For the first version, use the system keyboard’s Dictation control or type normally. A dedicated **Dictate** button is a later enhancement.
3. See the transcript, stop dictation, and edit the wording before tapping **Add note**. Cancel leaves the screenshot unchanged.
4. Drag the committed note to refine its position; select it to edit or delete it. Return to the drawing tool to continue using Pencil.
5. **Done** composites the source screenshot, Pencil strokes, and text notes into the normal full-resolution PNG for the Mac and clipboard workflow.

Prefer this visible tool over a global long press, Pencil double tap, or squeeze. Existing PencilKit drawing, selection, tool switching, and two-finger pan gestures must remain predictable. A deliberate shortcut can be explored later, scoped to text-note mode and with an accessible button equivalent. Opening the composer must transfer first-responder focus away from the Pencil canvas so the keyboard can remain open.

### Staged scope

**MVP — Editable notes plus system Dictation.** Add movable text overlays, a plain-text composer, and PNG export support. Apple documents Dictation as a text-entry option on iPad; a normal text editor lets the user invoke it through the keyboard. Dictation availability and processing follow the user’s device, language, and system settings. Do not promise that system Dictation is always offline or add app microphone permissions merely for keyboard input. No paid transcription provider or account is needed. [Apple: Dictate text on iPad](https://support.apple.com/guide/ipad/dictate-text-ipad997d9642/ipados).

**Later — An explicit in-app microphone control.** Add visible listening, stop, cancel, and editable transcript states only if the keyboard flow proves too slow. Evaluate `SpeechAnalyzer`/`SpeechTranscriber` on supported systems; Apple introduced SpeechAnalyzer in iOS 26 and describes its transcription as on-device. Check hardware, locale, and installed/downloadable model support rather than assuming every iPad supports the same path. The app currently targets iPadOS 18, so newer APIs require availability checks. [Apple: SpeechAnalyzer introduction](https://developer.apple.com/videos/play/wwdc2025/360/), [Apple: SpeechTranscriber capabilities](https://developer.apple.com/documentation/speech/speechtranscriber).

For an older-system implementation, evaluate `SFSpeechRecognizer`: require `supportsOnDeviceRecognition == true` before setting `requiresOnDeviceRecognition = true`. If local recognition is unavailable, keep typing/system Dictation available and explain the limitation; do not silently switch the app’s recorder to server recognition. Model downloads may require a network even when subsequent recognition is local. No paid service is part of the proposed default. [Apple: device support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [Apple: on-device requests](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition).

### Data, permissions, and drawing preservation

- Extend the local draft model with text-note IDs, content, position, bounds, and a small set of readable style choices. Store geometry in source-image coordinates; share the existing image/ink zoom transform. Keep notes editable and separate from `PKDrawing` until export. Decode old drafts with no notes; preserve existing strokes and source PNGs.
- Persist notes with the capture’s draft, including Previous/Next and Browse navigation, reopening, and retry recovery. Include note changes in dirty state and undo/redo. Render text at original image resolution, then use the existing export/save path and size limits.
- For the later app-controlled recorder, ask for microphone access only after **Dictate** is invoked, with `NSMicrophoneUsageDescription` explaining the purpose. The `SFSpeechRecognizer` path also needs its speech authorization and usage description. Apple distinguishes this from `SpeechAnalyzer` transcriber modules, which do not send voice audio to its servers. Request only permissions needed by the chosen implementation, never at launch. [Apple: microphone permission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)), [Apple: speech permission and first use](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition).
- Keep typed input available after denial or recognition failure. Stop recording on cancellation, navigation, interruption, or backgrounding; keep any transcript for review without automatically adding a note. Do not retain raw audio by default. Update the privacy policy before shipping app-controlled recording; never send screenshots to speech recognition.

### Acceptance checks and remaining coverage

- Existing drawings and original screenshots survive adding, moving, editing, deleting, undoing, and cancelling notes; old drafts still load.
- Notes stay anchored while panning, zooming, rotating the iPad, and opening the keyboard. Notes survive capture navigation and app restart.
- The saved PNG contains the same text, placement, and strokes at the original dimensions; clipboard delivery and upload retry still work.
- Pencil drawing and gestures never start recording accidentally. All note controls work with touch, keyboard, and VoiceOver.
- The user's physical-device Dictation → note + Pencil → Done → Mac paste check passed. Broader checks of Dictation disabled, other locales, and offline operation remain. For a future app-controlled recorder, also test permission denial, interrupted recording, and model availability. Make the fallback understandable and preserve work.

The first implementation uses editable note cards and keyboard Dictation. It includes Small/Medium/Large text, move/edit/delete, shared undo/redo, legacy draft decoding, navigation/restart recovery, and full-resolution PNG export. An open composer blocks navigation and session changes; navigation also stops if an in-memory draft cannot be saved. Unplaced composer text stays in the current editor while it is open; use Add note to save it in the persistent draft.

**Still in the backlog:** a dedicated in-app microphone button, a deliberate gesture shortcut, Safari parity, automatic rewriting/grading, voice commands, and continuous listening. No app-controlled recording or additional speech permissions have been introduced.
