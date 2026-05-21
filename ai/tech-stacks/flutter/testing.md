# Flutter Testing Rules

## Test Mix

- Unit tests cover repositories, contracts, adapters, and pure services.
- Widget tests cover user-visible state and interaction behavior.
- Integration tests cover full critical flows and performance replay.

## Baseline Gates

- `dart analyze` from `mobile/`.
- Targeted `flutter test` for touched files.
- Wider `flutter test` before claiming mobile-wide behavior is passing.

## Widget Test Rules

- Prefer `pump()` and bounded frame pumping over open-ended `pumpAndSettle()`.
- Use stable keys or semantics labels for important interactions.
- Complex migrated UI states need loading/error/empty/data coverage when practical.