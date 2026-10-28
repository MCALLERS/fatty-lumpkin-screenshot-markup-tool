# Screenshot landing website

Static, dependency-free landing page for `screenshot.bombadillo-ai.com`.

## Preview

From this directory, run `python3 -m http.server 8094 --directory public`, then open `http://localhost:8094`.

## Deploy

The site is live at https://screenshot.bombadillo-ai.com through Cloudflare Workers static assets. `wrangler.jsonc` binds the custom domain.

Cloudflare Builds is configured for this repository's `main` branch, with root directory `website`, no build command, and deploy command `npx wrangler@4.141.0 deploy`. Only changes matching `website/**` trigger a build; preview builds are disabled. GitHub installation access is confirmed, and commit `bf8242e` successfully built and deployed automatically on 28 October 2026.

For a manual deployment, run `npx wrangler@4.141.0 deploy` from this directory with the intended Cloudflare account authenticated.

## Maintenance

- Update both `data-download` links and the visible beta version in `public/index.html` when publishing a Mac release. Use a verified, signed/notarized DMG asset URL.
- The public native iPad TestFlight invitation is verified and linked. The currently approved version is 0.4.0; 0.5.0 (13) is waiting for review. Update the visible version note after Apple approves it. The Safari companion is also usable with the Mac download.
- Keep `public/privacy.html` consistent with `../docs/PRIVACY.md` when storage or networking changes.
- Artwork is the existing project illustration from `../Branding/pony-bookplate.png`; the workflow is a purpose-built, labeled illustration, not an app recording.
- No web analytics, third-party runtime dependencies, cloud screenshot relay, or generated media calls are included.
- Motion has pause/replay/step controls and honors `prefers-reduced-motion`. The page remains readable without JavaScript.
