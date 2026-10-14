# Architecture Preferences

- Prefers feature-first architecture for Flutter apps. Confidence: 0.9
- Organizes code into `core` (cross-cutting), `features` (domain slices), and `shared` (reusable UI) folders. Confidence: 0.85
- Uses Riverpod for state management. Confidence: 0.9
- Wants foundational layers set up up front: routing, a reusable theme system, shared widgets, and centralized error handling. Confidence: 0.8
- Likes each feature split into domain / data / presentation with providers co-located with the service or repository they expose. Confidence: 0.7
