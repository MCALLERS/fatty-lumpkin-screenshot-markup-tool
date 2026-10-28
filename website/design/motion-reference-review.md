# Motion references for Ludwig’s Annotated Screenshots

Reviewed locally on 28 October 2026. The implementation uses original artwork and fictional interfaces. Private project names, chat references, and local source links are intentionally excluded from these public notes.

## Reusable choreography

1. **Disorder becomes a usable batch.** A scattered set of tiles can move into a clean grid using short transforms and a small stagger. For Ludwig’s, the useful pattern is screenshots accumulating into an organized set. The source documents and claims from reference work are not included.
2. **Draw a causal sequence, then concentrate attention.** Carry the same screenshot through capture, annotation, completion, paste, and review. Keep its identity stable and dim unrelated details when an action needs attention.
3. **A pen tip follows the ink.** Reveal each path progressively and keep the nib at the drawn endpoint. One path represents one continuous stroke. Lift the pencil between strokes instead of sliding it independently of its line.
4. **Leave time to read.** Brief holds after a grade, reason, or completed transfer make the sequence easier to follow. The hero’s repeating character gesture can stay lively while the explainer gives each step room.

## Implementation

The site uses its own deterministic 36-second canvas timeline with readable named stages and SVG/canvas marks tied to pen geometry. It includes pause, replay, seeking, chapter controls, offscreen/background suspension, reduced-motion behavior, keyboard access, and local assets.

The hero repeats a separate eight-second character gesture while visible. Its driver owns the animation clock; the character renderer accepts explicit time and creates no independent timer. Pause/resume retains position. A saved explicit motion choice can override or restore the device preference.

The grade and reason represent the human reviewer’s markup. The external AI revision is an illustrated example, not a built-in AI integration or a promised result. Reference films, private documents, presenter configuration, account files, and third-party claims are not copied into the public website.
