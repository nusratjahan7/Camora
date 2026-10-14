# Flutter / Dart Preferences

- Prefers using the latest mutually compatible *stable* package versions rather than pinning old ones. Confidence: 0.9
- Explicitly wants package APIs verified against the installed source before writing code, not written from memory (checks changelogs, signatures, and exported classes in the pub cache). Confidence: 0.9
- Wants native/platform compatibility (compileSdk, NDK, iOS macros/Podfile vs SPM) checked against the actual toolchain before committing to configuration. Confidence: 0.8
