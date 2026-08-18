# new_moca

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## MoCA subtest coverage

29 of 30 points are implemented. Cube copy is administered on paper.

Voice scoring (13 of those points) requires a `/transcribe` endpoint on the
backend, which is not deployed yet — until it is, those subtests can only be
skipped. Vigilance (1 point) needs no backend and scores today. See
[design_docs/CONTENT-STATUS.md](design_docs/CONTENT-STATUS.md) for the
`/transcribe` contract, the test content that must be changed in pairs, and
known limitations.
