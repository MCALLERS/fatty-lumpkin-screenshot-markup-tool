# Release procedure

1. Update versions in scripts/build.sh, NativeiPad/generate-project.py, and visible beta labels. Regenerate the Xcode project.
2. Run Python, Safari, native simulator, and Mac self-tests. Exercise the complete workflow on a real iPad with synthetic screenshots, including three captures, retry, reconnect, and final queue clearing.
3. Build the signed self-contained Mac app with scripts/package-mac.sh. Run scripts/verify-packaged-companion.py against it. Verify all Mach-O dependencies are bundled or system-provided and support the stated minimum OS.
4. Notarize the signed app zip using a locally configured notarytool Keychain profile. Staple the accepted ticket to the app. Create a DMG containing the app, an Applications link, setup guide, and license. Sign/notarize/staple the DMG. Validate with `stapler validate` and `spctl --assess --type execute` on the app.
5. Audit exactly the files staged for Git: no screenshots, pairing keys, private paths, device identifiers, certificates, logs, or runtime state. Push the reviewed MIT source and publish the signed DMG plus SHA-256 checksum as a GitHub prerelease. Download it again, compare checksums, mount it, and verify the downloaded app signature and runtime.
6. Archive the iPad Release scheme with your Apple team, then upload through Xcode’s App Store Connect distribution. The listing is **Fatty Lumpkin Screenshot Tool**, bundle `com.mcallers.screenshottool.ipad`.
7. Complete TestFlight test information, privacy URL, review notes, and review contact. Create an external beta group, submit its first build for Beta App Review, then enable a public invitation link after approval. Do not claim availability while processing or awaiting review.

Keep signing credentials, notary profiles, and Apple review contact information outside source control. Apple account agreements and account-holder compliance declarations must be handled by the account holder.

## Beta review notes

This iPad companion requires the free Mac companion, downloadable from the GitHub releases page. No app account is required. Both devices must be on the same trusted private network. Install the Mac app, set up its screenshot folder, choose Connect iPad, and scan the displayed QR code from the native iPad app. Capture with ⇧⌘4; annotate with Pencil or enable Finger drawing; tap Done; wait for copied confirmation and paste on Mac. For a batch, capture three screenshots and use Done & Next.

Camera access is only for QR scanning; Local Network access transfers screenshots directly between the user’s devices. No screenshot is uploaded to a developer server. The local connection is authenticated HTTP, without custom encryption. The companion does not directly integrate with an AI service; users choose where to paste their own images.
