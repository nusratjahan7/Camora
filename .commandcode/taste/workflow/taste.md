# Workflow Preferences

- Wants the agent to inspect the existing project and explain the proposed structure *before* implementing (plan/explain first, then build). Confidence: 0.85
- Wants available checks run (analyzer, tests, builds) and results reported. Confidence: 0.85
- Expects an end-of-task report covering files created, commands executed, and remaining issues/blockers. Confidence: 0.85
- Expects a README with installation, run-on-Android, and build-on-iOS instructions. Confidence: 0.8
- Prefers implementing in scoped modules/stages rather than delivering everything at once. Confidence: 0.7
- Wants unit tests for pure/non-trivial logic (e.g. coordinate-mapping and image-composition math), not just integration coverage. Confidence: 0.75
- Wants results verified on real Android and iOS devices where hardware is available, not only through host-side test runs. Confidence: 0.7
- When polishing or refactoring, wants existing working features preserved rather than replaced or rewritten. Confidence: 0.75
