# Architecture Preferences

- Prefers feature-first architecture for Flutter apps. Confidence: 0.9
- Organizes code into `core` (cross-cutting), `features` (domain slices), and `shared` (reusable UI) folders. Confidence: 0.85
- Uses Riverpod for state management. Confidence: 0.9
- Wants foundational layers set up up front: routing, a reusable theme system, shared widgets, and centralized error handling. Confidence: 0.8
- Likes each feature split into domain / data / presentation with providers co-located with the service or repository they expose. Confidence: 0.7
- Prefers keeping large binary assets (e.g. images) on disk and persisting only file paths plus lightweight metadata locally, rather than embedding image data. Confidence: 0.75
- Avoids loading large files into memory unnecessarily (e.g. decodes images at display/thumbnail size rather than full resolution). Confidence: 0.75
- Wants new features integrated with the existing modules (reusing their services/abstractions) rather than duplicated or siloed. Confidence: 0.65
