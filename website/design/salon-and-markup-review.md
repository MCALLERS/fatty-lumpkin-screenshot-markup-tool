# Continuous Ludwig, clearer markup, and the philosophy salon

28 October 2026. Local website changes; no deployment performed by this task.

## Changes

- The hero repeats its deterministic eight-second gesture while visible. Pause/resume retains the current position, and hidden/offscreen time does not accumulate. The saved site preference and reduced-motion behavior remain intact.
- The example heading is “Make your point. Right on the picture.”
- The fictional Fieldnotes screenshot and its annotations share one SVG coordinate system. A curved move arrow begins at the blue third card and ends at an insertion mark before the orange second card. A separate note requests a bigger, nicer headline font. The palette note and B+ grade remain.
- Example/Grade/Reasons/All together tabs update both the visible marks and the SVG’s accessible description.
- The philosophy section sits directly after the example. It combines the imagined Cambridge illustration, three short Tractatus propositions, a 1911 / 1921–22 / 1953 visual timeline, and expandable source/credit details.
- The later-work text explicitly describes the shift toward meaning in use and language-games. The 1953 date belongs to posthumous publication, while the archival portrait is captioned 1928–29.

Historical text and artwork provenance are documented separately in [philosophy-sources.md](philosophy-sources.md).

## Verification

The local VM lifecycle harness passes twenty checks. The hero check now verifies exact eight-second wrap, continued scheduling, pause/resume, and hidden/offscreen suspension. Existing saved preference, storage-failure, narration timing, mute, audio unlock, and BFCache checks also pass.

Chrome review covered the normal desktop viewport, 768px tablet, 390px phone, and 320px narrow width. There was no horizontal overflow at the checked widths. All four philosophy images loaded. The new markup layers and their accessible descriptions were verified through the real tab controls. The temporary viewport override was reset after review.

A live visible-hero check compared character-region screenshots 74.7 seconds apart. The rendered character changed, the control still read “Pause Ludwig,” and the page remained visible with the hero onscreen. This verifies sustained browser playback beyond the original single eight-second pass. The temporary browser tab was closed after testing.
