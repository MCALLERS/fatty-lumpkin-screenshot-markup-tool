# Ludwig’s Annotated Screenshots website

Static, dependency-free landing page for `screenshot.bombadillo-ai.com`.

## Preview

From this directory, run `python3 preview.py`, then open `http://127.0.0.1:8095`. Use `--port 8096` if the port is busy. The preview binds only to localhost, serves the extensionless privacy route, and applies the production security headers.

## Mac release — 28 October 2026

**Ludwig’s Annotated Screenshots 0.5.1** is published in [GitHub release v0.5.1-beta.1](https://github.com/MCALLERS/fatty-lumpkin-screenshot-markup-tool/releases/tag/v0.5.1-beta.1), with asset `Ludwigs-Annotated-Screenshots-0.5.1-arm64.dmg`. A fresh download from the public URL passed the portable SHA-256 checksum, app and DMG signatures, stapled notarization tickets, Gatekeeper assessment, the Mac self-test, and the isolated companion-protocol checks. Its SHA-256 is `563cc48d601775babfc11b72369c11d05a701e6d24d2114256171beb9d22a901`.

All main calls to action lead to the one `#download` section. It offers the Mac DMG, three inline setup steps using Safari on iPad without TestFlight, the full setup guide, and the optional native iPad TestFlight invitation. The page distinguishes the currently approved iPad 0.4.0 (11) from renamed 0.5.1 (14), which is waiting for Apple review. Local build 15 has not been uploaded and is not advertised as a public download.

For future updates, publish and verify the intended release asset before pushing a website download-link change to the auto-deployed branch. Then check the live page, privacy route, local assets, and exact downloaded DMG/checksum.

## Deployment configuration

The site is live at https://screenshot.bombadillo-ai.com through Cloudflare Workers static assets. `wrangler.jsonc` binds the custom domain.

Cloudflare Builds is configured for this repository's `main` branch, with root directory `website`, no build command, and deploy command `npx wrangler@4.141.0 deploy`. Only changes matching `website/**` trigger a build; preview builds are disabled. GitHub installation access is confirmed, and commit `bf8242e` successfully built and deployed automatically on 28 October 2026.

For a manual deployment, run `npx wrangler@4.141.0 deploy` from this directory with the intended Cloudflare account authenticated.

## Maintenance

- Update the `data-download` link and visible beta version in `public/index.html` when publishing a Mac release. Use a verified, signed/notarized DMG asset URL.
- The public native iPad TestFlight invitation is verified and linked. The currently approved version is 0.4.0 (11); Ludwig’s Annotated Screenshots 0.5.1 (14) is in the existing Public Beta group and waiting for review. Update the visible version note after Apple approves it. The Safari companion is included with the Mac download and needs no TestFlight.
- Keep `public/privacy.html` consistent with `../docs/PRIVACY.md` when storage or networking changes.
- The new Ludwig artwork is `public/assets/ludwig-portrait.png`; generation notes are in `design/ludwig-image-prompt.md`. The 36-second canvas explainer is drawn by `public/film.js`; it is an explicitly labeled illustration with fictional interfaces, not an app recording.
- `public/character.js` animates the existing portrait with an eight-second drawing gesture. `public/hero.js` starts it on arrival and loops continuously while visible, with Pause/Resume controls. A saved site motion choice can override or restore the device preference. `public/music.js` supplies original Web Audio music and local narration synchronized with film playback. Sound is on by default; a real click unlocks it when browser autoplay policy requires that. The six local narration clips use the owner’s Sarcastic Old Man voice; music ducks beneath speech. Fish Audio is used only by the private local generation helper, never by the website.
- The central workflow is capture on Mac → annotate on iPad → Done → Command-V into the chosen conversation → Send. One screenshot at a time is primary; batches remain a secondary option. Clipboard destinations include AI agents and other image-capable conversations. See `design/feedback-2026-10-28.md` and `design/motion-reference-review.md`.
- The published Mac app is Ludwig's Annotated Screenshots 0.5.1 (14); the installed local iPad app is 0.5.1 (15), adding artwork, quotes, and Clear queue. The existing App Store Connect record has been renamed, and iPad build 14 is waiting for review. Build 15 has not been uploaded. The Mac release uses the renamed asset; the currently approved native iPad download still has earlier branding. Bundle identifiers and screenshot storage remain unchanged; see `../docs/RELEASE-0.5.1.md` and `../NativeiPad/LOCAL-BUILD-15.md`.
- Bodoni Moda and Instrument Sans fonts are served locally; their SIL Open Font License notices are next to the WOFF2 assets. See `design/ludwig-direction.md` for reference sources and the philosophical framing.
- No web analytics, third-party runtime dependencies, cloud screenshot relay, or runtime generated-media calls are included. Only the optional motion preference is stored in this browser.
- Motion has pause, replay, seek, and scene controls. It honors `prefers-reduced-motion`, pauses offscreen/when hidden, and permits intentional Play/Replay in reduced-motion mode. The illustrated example also has keyboard-operable annotation layers. The page and explainer transcript remain readable without JavaScript.
- Public design notes retain artwork prompts, public reference URLs, and implementation details. Private chat identifiers, account-specific voice metadata, local generated-image paths, and unrelated project links are excluded. Only final narration MP3s and their public timing manifest ship; private generation helpers and account records are not part of the website.
- The existing production auto-deploy configuration remains unchanged. Production deployment and physical-device workflow checks are separate from local preview and package verification.
