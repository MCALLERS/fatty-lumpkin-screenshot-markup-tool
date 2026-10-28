# Ludwig’s Annotated Screenshots: landing-page direction

Working direction and implementation notes, 28 October 2026.

## Brand and message

The user-selected name is **Ludwig’s Annotated Screenshots**. The primary promise is **“Show your agent what good looks like.”** The supporting phrase is **“Show, don’t tell.”**

The product story connects four distinct contributions: an example supplies a shared reference; a handwritten grade states a reaction; a mark points to the relevant detail; a reason explains what to keep or change. The seamless loop is the primary value: capture an example on Mac, draw on iPad, tap Done, then press Command-V into the chosen conversation and Send. One screenshot at a time is primary. Several annotated examples can also form a visual brief. Clipboard delivery keeps the destination open, including an AI agent, Slack, or WhatsApp. The workflow continues through inspection of the next version.

## Design references actually consulted

- [Skillry: Obsidian Cinema Landing](https://skillry.dev/skills/bs-obsidian-cinema-landing), version 1.0.2. The reviewed materials were `SKILL.md`, `references/style-guide.md`, `references/motion-system.md`, and `references/quality-checklist.md`. Relevant influence: Bodoni Moda with Instrument Sans, cinematic pacing, a substantial film section, meaningful tab controls, pause/reduced-motion behavior, and local assets. The final composition follows the user’s illustrated early-Wittgenstein direction rather than reproducing the package’s headphone campaign.
- [Futurepedia AI Style Atlas](https://www.futurepedia.io/resources/ai-style-atlas/view), **Editorial Essay Collage Explainer, #11**. Its motion example and screenshot description were reviewed. Relevant influence: paper fragments, editorial type, marginal annotations, diagrams, and a visual essay sequence. The full source and prompt were not copied.

The visual treatment combines warm paper, dark ink, vermilion corrections, an editorial character illustration, and fictional example interfaces. The desktop hero remains legible before animation. The 36-second explainer is an original canvas sequence with playback, seeking, chapters, and a written transcript.

## Screenshot review revision

The seven annotated screenshots led to full-name branding, a stronger screenshot-and-pencil icon, larger brand descriptor, active character and Pencil animation, recognizable Mac/iPad devices, in-image feedback, and a complete Done → copied on Mac → Command-V → Send sequence. The phone-shaped comparison is a reference display, not a claim of native iPhone annotation support.

The character animation uses the existing artwork with a short head and writing-hand gesture. The hero starts on arrival and loops while visible, with pause/resume. Ludwig looks down while drawing, briefly glances up, and returns to the page. An explicit Play choice is remembered for this site; the visitor can restore the device motion preference. Film playback, chapter selection, seeking, reduced-motion handling, and optional music are local browser code. Music is an original Web Audio composition. Narration uses six local clips rendered with the owner-approved Sarcastic Old Man voice; the score ducks beneath the voice. Sound is enabled by default, with a first-click fallback when browser autoplay is blocked. General motion principles are recorded in `motion-reference-review.md`; private reference-project details are excluded.

## Tractatus reference

> The picture is a model of reality.

Ludwig Wittgenstein, *Tractatus Logico-Philosophicus*, proposition **2.12**, 1922 English edition associated with C. K. Ogden and F. P. Ramsey. [Source text](https://wittgensteinproject.org/w/index.php/Tractatus_Logico-Philosophicus_(English)#2.12).

The source text was opened and proposition 2.12 was verified. Nearby propositions explain that picture elements stand for objects and that their arrangement represents a possible arrangement of things. The landing page describes the app as a playful inspiration from that representational idea. It does not attribute claims about AI prompting, visual information density, or grading designs to Wittgenstein. “The form of the good” is not used as a quotation from the Tractatus.

## Assets and privacy

The young Ludwig portrait is generated artwork, not a historical photograph. See `ludwig-image-prompt.md` for its exact prompt and provenance. It was made with the built-in image generator. No separately paid API or CLI generation was used for this asset.

The Fieldnotes interfaces, feedback notes, diagrams, and batch sheets are fictional demonstration content. No private project screenshots or user annotations were added to the public site assets. The film is explicitly described as an illustrated workflow rather than an app recording, and its depicted AI revision is illustrative.

Fonts and runtime images/scripts load from the site itself. The page has no AI upload integration, account form, analytics SDK, or third-party tracking script. Users choose their AI destination. Existing transport limitations remain disclosed in the privacy information.

## Release boundary

The user has authorized publication of the redesigned website and renamed Mac beta. The planned download is Ludwig’s Annotated Screenshots 0.5.1 under GitHub tag `v0.5.1-beta.1`. The signed, notarized local artifact has been validated; the release upload and website deployment are still pending completion in this preparation record.

The publicly approved native iPad beta remains 0.4.0 (11). Renamed 0.5.1 (14) is awaiting Apple beta review; build 15 is local and has not been uploaded. The Safari companion is included with the Mac app and requires no TestFlight installation. Bundle identifiers, pairing, drafts, screenshot folders, and the repository remain stable. See `../../docs/RELEASE-0.5.1.md` for native distribution evidence. Review status is a dated snapshot.
