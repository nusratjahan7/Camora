# Product & UX Preferences

- Requests runtime permissions only when needed and wants the reason explained to the user (rationale) before/at the point of the system prompt. Confidence: 0.85
- Avoids unnecessary backend, authentication, and cloud services — prefers on-device/no-account solutions. Confidence: 0.8
- Wants polished dark themes with accessible controls (adequate tap targets, semantics labels). Confidence: 0.7
- Wants user media preserved faithfully: original capture dimensions and format kept, no unnecessary resizing/recompression, and the default (untouched) output behavior left unchanged. Confidence: 0.8
- Favors minimal-friction flows: after an action (e.g. a photo capture) completes it should just finish and return to the live/primary view — no separate review or confirmation screen that must be dismissed. Confidence: 0.7
- Wants the UI kept quiet: no success toast/snackbar confirming an action (e.g. after a photo capture) — inherent feedback like the shutter flash and haptic is enough, and messages are reserved for failures. Confidence: 0.75
- Wants edge cases handled explicitly and gracefully: missing files, permission errors, and empty states. Confidence: 0.7
- Wants visually similar variants clearly distinguished in the UI (e.g. badging an original photo apart from a composite export). Confidence: 0.6
- Expects every visible control to be functional — no decorative or placeholder controls that do nothing. Confidence: 0.8
- Wants layouts responsive across screen sizes and across portrait and landscape, respecting safe areas and avoiding overflow. Confidence: 0.7

- Wants the live preview framing to match the saved output — the crop shown while composing is the crop that is captured and saved. Confidence: 0.7
- Wants the app to clearly distinguish underlying technical reality (e.g. the display-only preview crop vs the sensor's true capture resolution). Confidence: 0.6
- Wants unrelated user state preserved when a setting changes (e.g. overlay opacity/position/scale/rotation/lock unaffected by a ratio switch). Confidence: 0.6
