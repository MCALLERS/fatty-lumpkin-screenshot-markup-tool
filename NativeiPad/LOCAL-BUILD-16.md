# Local iPad build 0.5.1 (16)

This development update fixes the previous/next arrows on the empty workspace. It is not a TestFlight release and does not change the published Mac download or website.

## Behavior

After finishing the last pending screenshot, the canvas returns to the welcome screen while saved screenshots remain in the current session. Build 15 required an active selection for both arrows, so they did nothing in that state.

- With no selection, the left arrow opens the newest screenshot and the right arrow opens the oldest.
- With a screenshot open, the arrows move chronologically without wrapping. An unavailable direction is visibly dimmed.
- Empty sessions disable both arrows. In a one-image session, either arrow opens the image; both disable once it is selected.
- Navigation still uses the existing draft-preserving open path and save/load guards. A selected draft whose original is absent from the current library retains the previous behavior instead of silently jumping elsewhere.

The existing pairing, bundle identifier, local drafts, and Mac protocol are unchanged. No screenshot reset, cleanup, or deletion is part of this update.

## Verification

Three new simulator regressions failed against build 15's navigation logic, then passed after the fix. All **24 native tests** passed, including existing ink preservation, manual browsing, failed opening, session reset, and clipboard safeguards.

Private local evidence: `work/navigation-before-16.log`, `work/navigation-before-16.xcresult`, `work/navigation-after-16.log`, and `work/navigation-after-16.xcresult`.

The Apple Development archive succeeded at `build/Ludwig-0.5.1-16.xcarchive` and was installed in place on the connected iPad. Physical tapping of the arrows and Pencil use still require a user workflow check; automated tests used synthetic screenshots and did not touch the real library.

The proposed spoken-text annotation feature is recorded in [the product backlog](../docs/BACKLOG.md). It is not implemented in this build.
