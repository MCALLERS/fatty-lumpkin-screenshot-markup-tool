# Local iPad build 0.5.1 (15)

This local development build is separate from **0.5.1 (14)**, which remains the App Store Connect build submitted to Beta App Review. Build 15 has not been uploaded to TestFlight.

## What changed

- A Ludwig drawing illustration welcomes the user in the empty workspace. A small portrait and a short attributed Tractatus quotation sit below the drawing canvas.
- Quotes advance when the workspace opens or an image successfully finishes. There is no automatic timer or motion while drawing. The information button opens context and the source of the three 1922 Ogden/Ramsey quotations (2.1, 2.12, and 4.1212).
- **Clear queue** is visible beside **Browse**. Its confirmation resets the current session to zero while keeping original screenshots and finished PNGs on the Mac, and unfinished drawings on the iPad under **Browse → To do**. It does not invoke the file-cleanup API.
- A current Pencil stroke is saved durably before the reset request. A local write failure leaves the drawing and queue in place. Failed reset requests reuse their identifier, including after restarting the app. Saving, loading, and clipboard acknowledgement block clearing until complete.
- The existing **Session** tools retain their separate, explicit review-and-confirm flow for moving older Mac files to Trash.

## Verification

- A new queue/draft regression failed before implementation and passed afterward.
- All **21 behavioral native tests** passed, including three new queue regressions, plus clipboard and prior workflow checks.
- Synthetic offscreen native previews were inspected in landscape, portrait, and narrow layouts. The temporary preview-render harness was removed after capture; it is not app functionality or a permanent test.
- No server or protocol change is required. Existing pairing, storage, bundle identifiers, and drafts remain compatible.

Physical-device Pencil → Done → Mac paste still needs a user workflow check. No real screenshot queue was cleared during development or verification.

## Local installation

The Apple Development-signed archive succeeded at `build/Ludwig-0.5.1-15.xcarchive`. It was installed in place on the connected physical iPad. A fresh device metadata query verified **Ludwig's Annotated Screenshots**, version **0.5.1**, build **15**, with the unchanged bundle identifier `com.mcallers.screenshottool.ipad`.

Installation and metadata verification succeeded; no screenshot queue was cleared and no Pencil handoff was performed on the user's device. Build 15 was not uploaded to App Store Connect or submitted for review. Build 14 remains the separately submitted TestFlight build.
