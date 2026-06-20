# Phase 41 Runnable Slice Proof

## Construction result

`mobile_v2/lib/main.dart` launches exactly one `ProviderScope` containing
`BabyTalkApp`. The app opens `shoes_on_room_v1` directly and projects the sole
session state through the approved D.4.5 Ritual Room screen.

The runtime uses:

- approved D.4.5 geometry reference:
  `.planning/phases/41-mobile-v2-runnable-vertical-slice/assets/prototypes/phase41-d4-5-interaction-engine.png`
- approved static illustration:
  `mobile_v2/assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png`
- one stable ritual identity, one current utterance, one action cue, one listen
  control, neutral reaction tray/sheet, reassurance, and quiet exit
- loading, ready, submitting, revised, recoverable-error, and retry behavior
- alternate payload substitution through repository/provider overrides
- 390x844 geometry, text scale 1.3, explicit semantic labels, and 48x48 minimum
  touch targets

## Fresh gate evidence

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | pass; 88 files, 0 changed |
| `flutter analyze --no-pub` | pass; no issues |
| `flutter test --no-pub` | pass; 113/113 |
| `dart run tool/verify_mobile_v2_semantic_firewall.dart` | pass; 59 runtime files, 0 violations |
| `dart run tool/verify_activation_governor_contract.dart` | pass; 5 cases, 0 violations |

mobile_v2_semantic_firewall_status=pass

activation_governor_contract_status=pass

## Requirement trace

| Requirement | Runnable evidence |
|---|---|
| R058 | Direct family micro-ritual surface; tests reject First Entry/Today Orientation navigation, course, task, progress, score, and infinite-generation framing. |
| R059 | Stable `shoes_on_room_v1` identity and one current caregiver utterance remain visible across revisions; no phrase list or activity-completion flow exists. |
| R060 | Observations flow as non-diagnostic engine evidence; the UI renders only authoritative snapshots and retains no raw voice/free-text input. |
| R063 | Content carries prior `allow_activation` evidence only; the Activation Governor verifier passes and no UI/runtime bypass was added. |
| R064 | No scoring, check-in, completion, reward, or production Garden transition exists; the Garden/activation verifier passes. |
| R065 | The screen supports the already-approved active room without adding Explore-to-Activate controls or action-now recommendation authority. |
| R067 | All five typed channels execute through revision 5 while the Phase 41 capability mask exposes reaction selection only. |

## Source and scope audit

- `main.dart` contains exactly one `ProviderScope`.
- `BabyTalkApp` watches only session state and capability mask.
- Reaction callbacks create typed `InputEvent` values through
  `interactionInputFactoryProvider` and submit through the sole notifier.
- `ritual_room_screen.dart` imports no Riverpod, data layer, DTO, mock,
  repository implementation, or fixture.
- Presentation contains no microphone, free-text field, future-signal control,
  strategy tray, lesson progression, task, progress, score, or Garden UI.
- Phase 42 controls were not implemented.
- No Spring endpoint was implemented.
- No real LLM integration was implemented.
- No persistence was implemented.
- No production Garden transition was implemented.
