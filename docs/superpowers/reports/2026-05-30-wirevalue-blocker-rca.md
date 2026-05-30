# WireValue Blocker RCA (2026-05-30)

## Symptom

`cd mobile && flutter test test/widget_test.dart` failed to compile with:

`The getter 'wireValue' isn't defined for the type 'BabyReactionType'`

## Root Cause

`wireValue` is provided by extension `BabyReactionTypeWire` in `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`, but `mobile/lib/app/providers/repository_providers.dart` used `e.reactionType.wireValue` without importing that extension library.

## Minimal Fix

Add the missing import in `mobile/lib/app/providers/repository_providers.dart`:

`package:mobile/features/practice/domain/models/interaction_event_payload.dart`

## Guard

Add `mobile/test/features/practice/interaction_event_payload_test.dart` to verify `BabyReactionType` wire mapping (`wireValue` and `parseBabyReactionType`) remains consistent.