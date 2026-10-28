# Ludwig’s narration draft

Prepared and generated 28 October 2026 with explicit approval. Six processed local narration clips are ready for the planned website publication. No new speech generation is part of this publication step.

Voice: **Sarcastic Old Man**, the owner-approved custom voice. Account ownership, voice identifiers, credentials, and verification records remain private. Reuse of the selected voice requires access to the private production configuration.

Delivery: lightly wry, unhurried, and helpful. Small pauses carry the jokes. Keep “Done,” “Copied on your Mac,” and “Command V” clear. Avoid a theatrical caricature or laughter. The voice name describes the selected voice; it is not a prompt to ridicule the viewer.

| Film time | Narration | UTF-8 bytes |
| --- | --- | ---: |
| 0–5 s | Move that button. No, the other one. Marvellously specific. | 59 |
| 5–9 s | Or... show what you mean. A radical notion. | 43 |
| 9–15 s | Capture on your Mac. There it is on your iPad, ready for your Pencil. | 69 |
| 15–22 s | Give it a grade. Circle the problem. Say why. B plus: good idea, a little loud. | 79 |
| 22–30 s | Tap Done. Wait for "Copied on your Mac." Command V into your chat. Then send. | 77 |
| 30–36 s | Review the next version. Keep what works. Mark what doesn't. Repeat. Now we're getting somewhere. | 97 |

**77 words; 424 UTF-8 bytes across six requests** (429 bytes if joined with five line breaks). The film is 36 seconds, approximately 128 words per minute including pauses. Scenes were generated separately so pauses and the handoff align without stretching the whole narration. All six initial takes fit after edge-silence trimming; the final scene uses a modest 1.02718× tempo adjustment. No phrases were shortened and no retakes were needed.

## Production and public deliverables

Narration was rendered locally through Fish Audio using the explicitly selected voice and model. The website never calls a speech-generation service. Only completed audio and safe scene timing are published. See the provider’s public [TTS documentation](https://docs.fish.audio/api-reference/endpoint/openapi-v1/text-to-speech) for general API behavior.

An optional private local generation helper verifies the selected voice, enforces an approved spending limit, and avoids automatic retries after uncertain requests. It is not part of this public repository. Raw masters, account verification, credentials, and spending records are excluded from publication.

Processing trims edge silence, allows a small tempo adjustment when necessary, verifies that each clip fits its scene, and decodes the completed MP3 before replacing a public output. Existing completed takes are reused unless a new generation is separately authorized.

The shipped files are `public/assets/audio/narration-01.mp3` through `narration-06.mp3`, plus `narration-timing.json`. The manifest contains only each scene’s index, start, end, measured duration, applied speed, public source path, and spoken text. Scene starts remain `[0, 5, 9, 15, 22, 30]`.

Sound is enabled by default with a browser-gesture fallback when autoplay is blocked. Playback follows the film’s pause, seek, visibility, and chapter state. The original Web Audio score ducks beneath narration.

## Generated audio checks

All six final MP3s are mono, 44.1 kHz, and 192 kbit/s. Each passed full FFmpeg decode and fits inside its assigned scene. Measured loudness stays within 0.44 LU of the −18 LUFS target; measured true peaks remain below −3.5 dBTP. These are technical audio checks; final voice taste and its balance against music should be reviewed in the integrated page.

| Clip | Start | Measured duration | Tempo | LUFS | True peak (dBTP) |
| --- | ---: | ---: | ---: | ---: | ---: |
| narration-01.mp3 | 0 s | 4.3187 s | 1× | −17.68 | −3.58 |
| narration-02.mp3 | 5 s | 3.1886 s | 1× | −18.44 | −4.85 |
| narration-03.mp3 | 9 s | 4.3840 s | 1× | −18.22 | −4.54 |
| narration-04.mp3 | 15 s | 6.5464 s | 1× | −18.04 | −4.02 |
| narration-05.mp3 | 22 s | 5.9374 s | 1× | −18.06 | −4.05 |
| narration-06.mp3 | 30 s | 5.9281 s | 1.02718× | −18.22 | −3.70 |
