# Ludwig character renderer

`website/public/character.js` animates the original transparent portrait with a second, generated eye-gaze cel. It does not edit or replace the original PNG, call an image/video API at runtime, load a library, or own an animation clock.

## Public interface

```js
const available = await window.LudwigCharacter.ready;
if (available) {
  window.LudwigCharacter.draw(ctx, {
    x: 0,
    y: 0,
    width: 640,
    time: elapsedSeconds,
    drawInk: true
  });
}
```

- `ready` resolves `true` when the original local image is loaded and the mesh is prepared; it resolves `false` if the original image fails to load. If the optional down-looking asset fails, the original portrait remains available as a fallback.
- `draw` returns `false` before the asset is ready or for invalid/nonpositive width, otherwise `true`.
- The output box is 4:3: its height is `width * .75`. The original image is 1448 × 1086.
- Time is seconds, can be any finite number, and repeats every 8 seconds. The renderer is deterministic at an explicit time. A fixed time produces a still frame.
- `drawInk` defaults to `true`; set it to `false` to keep the character movement without the additional notebook mark.
- The context is saved and restored. Caller transforms, opacity, compositing, and device-pixel-ratio scaling are preserved.
- The caller clears the destination canvas and owns RAF, playback speed, pause, offscreen handling, and reduced-motion behavior. Keep the original portrait as a fallback if the renderer is unavailable.

The homepage hero now repeats continuously while visible. Its driver wraps elapsed time modulo eight seconds without stopping or rebuilding the character. The renderer already returns the hand to its original pose and fades the ink before the wrap. Pause/resume retains the current position; hidden tabs and offscreen placement suspend elapsed time. A saved explicit site motion choice still takes precedence over the device preference.

## Movement

The default pose looks down at the notebook. The head inclines and drops toward the page. The drawing hand and red pencil move through an oval, lift, and return. A small breathing displacement connects the pose. Red ink appears along the nib path and fades before the loop resets.

During each 8-second cycle, Ludwig glances toward the viewer from approximately 5.35 to 6.275 seconds, then returns to the page. The head lift and drop ease smoothly around those gaze changes. The eye drawing changes cleanly between two aligned cels; there is no crossfade of pupils or artificial eyelid squash. Most of the cycle, including time zero, uses the downward gaze.

Only a 270 × 145 pixel feathered region around the eyes is sampled from `assets/ludwig-looking-down.png`, aligned in runtime canvas. The edited image’s hair, body, arms, hands, notebook, and silhouette are never substituted. Its eye patch follows the same continuous head mesh as the original artwork.

This is continuous deformation of one image, using a weighted mesh, rather than overlapping cutout limbs. Head, torso, hand, pencil, and nearby paper remain joined. The ink path is registered to the actual piecewise-affine position of the nib. The other hand remains substantially still.

## Cost and inspection

The grid contains at most 280 triangles. Transparent cells are discarded once on image load when canvas readback is allowed; otherwise the full mesh is used. Source rectangles limit each triangle draw, and small clip overlaps prevent hairline cracks. No external runtime dependencies or self-driven timers are created.

Browser inspection used a temporary localhost-only test page with an explicit-time slider and side-by-side poses. The original PNG alpha is preserved, no visible triangle seams or duplicate limbs appeared, and the mid-stroke hand pose was checked at 2.8 seconds. The down-looking pose was inspected at 2.8 seconds and the upward glance at 5.8 seconds. On this Mac’s Chrome, the test page reported approximately 0.8–0.9 ms average JavaScript draw-call time at a 1448 × 1086 backing canvas. This does not measure complete GPU frame/compositing cost and is not a cross-device performance guarantee.

`node --check website/public/character.js` passed. The renderer is intentionally a restrained illustrated movement, not a photorealistic character rig or lip-synced video.

## Down-looking asset provenance

The second cel was edited with the built-in image generator on 28 October 2026, with the original portrait supplied as the reference and `transparent_background: true`. No paid external API or CLI was used. The source was inspected before editing, and the final asset was copied into the project without pixel editing or resampling.

- Final file: `website/public/assets/ludwig-looking-down.png`
- Dimensions: 1448 × 1086, RGBA PNG.
- The generated original is retained privately; the shipped asset and edit prompt are documented here.

### Exact edit prompt

```text
Use case: identity-preserve
Asset type: precisely registered alternate gaze pose for a canvas-animated editorial illustration.
Edit the supplied transparent PNG. Change ONLY Ludwig's eyes and eyelids so that he is clearly looking DOWN at the open notebook and red pencil tip in front of him, instead of looking at the viewer. His gaze should be naturally lowered and slightly toward the pencil side (viewer left). Upper eyelids lower naturally over the irises, with a thoughtful absorbed expression. Keep eyes naturally open enough to read as looking down, not sleeping or blinking.
CRITICAL INVARIANTS: Keep the exact same image dimensions, framing, subject silhouette, head position, head angle, hair, face shape, nose, mouth, neck, shirt, waistcoat, arms, both hands, pencil, open notebook, all existing drawings, transparent background and alpha silhouette. Do not move, scale, redraw, restyle or reposition any other part. This is an alternate eye-gaze animation cel of exactly the same drawing, so pixel alignment matters. Do not rotate or lower the entire head. Preserve every part outside the eye/eyelid region as closely as possible. Match original ink etching, warm cream, black ink and vermilion pencil precisely. No new text or objects. Output a transparent PNG.
```
