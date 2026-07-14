# Phase 41 Pattern Map

**Updated:** 2026-06-19
**Authority:** `mobile_v2/AGENTS.md`, `mobile_v2/CODING_STANDARDS.md`,
`41-CONTEXT.md`, `41-INTERACTION-ENGINE-CONTRACT.md`, and
`41-SCHEMATIC-DESIGN.md`

## Current Pattern

Phase 41 uses a feature-first layered Flutter structure:

```text
MockRitualContentApi
  -> RitualRoomResponse
  -> RitualRoomMapper
  -> RitualRoomRepositoryImpl
  -> RitualRoomContent

RitualContextInput
  -> RitualInteractionMapper
  -> RitualInteractionRequest
  -> MockRitualInteractionApi
  -> RitualInteractionResponse
  -> RitualInteractionMapper
  -> RitualInteractionRepositoryImpl
  -> RitualInteractionSnapshot

RitualRoomContent + RitualInteractionSnapshot
  -> RitualRoomController
  -> RitualRoomScreen
```

The durable feature name is `ritual_room`. Historical
`first_micro_ritual`, lens-flow, phrase-card, and practice-session examples are
superseded and must not be used by executors.

## Artifact Map

| Artifact | Role | Dependency rule |
|---|---|---|
| `data/datasources/ritual_content_api.dart` | replaceable backend-shaped source contract | no Flutter UI dependency |
| `data/datasources/mock_ritual_content_api.dart` | async demo adapter loading the local JSON fixture | depends on data DTOs only |
| `data/datasources/ritual_interaction_api.dart` | replaceable evolving-interaction source contract | no Flutter UI dependency |
| `data/datasources/mock_ritual_interaction_api.dart` | async capability-complete demo engine | handles every interaction request channel |
| `data/dto/ritual_room_response.dart` | transport-only response shape | never imported by presentation |
| `data/dto/ritual_interaction_request.dart` | transport-only multi-channel request shape | produced by mapper; never imported by presentation |
| `data/dto/ritual_interaction_response.dart` | transport-only revised snapshot shape | never imported by presentation |
| `data/mappers/ritual_room_mapper.dart` | validates and maps transport to domain | one-way DTO -> domain |
| `data/mappers/ritual_interaction_mapper.dart` | domain input -> request and validated response -> snapshot | bidirectional only at repository boundary |
| `data/repositories/ritual_room_repository_impl.dart` | coordinates source and mapper | implements domain repository |
| `data/repositories/ritual_interaction_repository_impl.dart` | advances interaction through source and mapper | implements interaction repository |
| `domain/models/ritual_room_content.dart` | immutable presentation-ready ritual content | no data or Flutter dependency |
| `domain/models/ritual_context_input.dart` | typed reaction/voice/text/future-signal/strategy envelope | every variant executes; UI exposes reaction only |
| `domain/models/ritual_interaction_snapshot.dart` | accumulated interaction revision and current output | immutable; no widget-owned history |
| `domain/models/ritual_utterance_suggestion.dart` | one complete current caregiver utterance | no data or Flutter dependency |
| `domain/models/ritual_memory_prompt.dart` | optional post-exit prompt/options and local parent choice | no persistence or production Garden transition |
| `domain/repositories/ritual_room_repository.dart` | domain-facing content contract | consumed by controller |
| `domain/repositories/ritual_interaction_repository.dart` | domain-facing interaction advance contract | consumed by controller |
| `presentation/controllers/ritual_room_controller.dart` | single owner of load/submit/retry and optional post-exit state | depends on both domain repositories |
| `presentation/screens/ritual_room_screen.dart` | composes the approved single-screen interaction projection | consumes room content and interaction snapshot |
| `presentation/widgets/ritual_identity_header.dart` | short illustration + ritual identity header | consumes smallest domain slice |
| `presentation/widgets/ritual_action_cue.dart` | one snapshot-owned action / TPR timing cue | no DTO/mock/fixture imports; never renders a list |
| `presentation/widgets/ritual_submitting_indicator.dart` | small inline pending state while preserving current output | no full-screen loading replacement |
| `presentation/widgets/ritual_listen_control.dart` | generic play/pause affordance | callbacks and generic labels only |
| `presentation/widgets/ritual_reassurance.dart` | low-pressure parent permission copy | content supplied by domain model |
| `presentation/widgets/ritual_current_utterance.dart` | primary current output | content supplied by interaction snapshot |
| `presentation/widgets/ritual_context_input_tray.dart` | inline neutral context choices and additional-choice sheet | dispatches typed inputs only |

## UI Composition Pattern

`RitualRoomScreen` is one scrollable Material surface:

1. Stable compact Ritual identity and anchor.
2. One current complete utterance as the primary output focus.
3. One current action / TPR timing cue without a list or lesson progression.
4. A small set of text-only neutral context choices and a half-height bottom sheet.
5. In-place submitting/revised/retry behavior that preserves the last usable utterance.
6. Concrete reassurance and quiet `先这样就好` exit.

Do not turn the current utterance, action cue, or context input into competing
cards. Use typography, spacing, and alignment before borders or elevation. The
single current utterance is the only dominant body output.

## State Pattern

The controller exposes an immutable sealed-style state:

- loading
- ready with `RitualRoomContent` and `RitualInteractionSnapshot`
- submitting context while preserving the last usable output
- recoverable load or submit error
- revised ready snapshot with monotonic revision
- optional post-exit Memory Lens state only if retained
- optional local `ParentMemoryChoice` after the post-exit prompt

Retry belongs to the controller. Content values never appear in controller
branches.

## Testing Pattern

Tests mirror source ownership:

```text
test/features/ritual_room/
  data/
    datasources/ritual_content_api_test.dart
    datasources/ritual_interaction_api_test.dart
    mappers/ritual_room_mapper_test.dart
    mappers/ritual_interaction_mapper_test.dart
    repositories/ritual_room_repository_test.dart
    repositories/ritual_interaction_repository_test.dart
  presentation/
    controllers/ritual_room_controller_test.dart
    screens/ritual_room_screen_test.dart
    widgets/ritual_room_support_widgets_test.dart
    ritual_room_accessibility_test.dart
```

Required evidence:

- source returns one async transport response
- malformed required transport data fails explicitly
- mapper/repository expose domain models, not DTOs
- controller covers loading -> ready and error -> retry -> ready
- controller covers ready -> submitting -> revised ready
- every input variant maps to a transport request and advances the engine
- mixed-channel sequential inputs increment revision, accumulate context, and
  evolve strategy/output
- the UI exposes only reaction without constraining engine capability
- two safe payloads render different content
- exactly one current utterance and at most one action cue render at a time
- long utterances wrap without clipping controls
- text and audio controls expose semantic playback labels
- controls meet 48x48 minimum touch targets
- forbidden lesson, progress, child-performance, and reward semantics are absent

## Reference-Only Old Mobile Material

The following files may inform tone or interaction but cannot be imported into
`mobile_v2/lib`:

- `mobile/lib/app/theme/app_theme.dart`
- `mobile/lib/app/widgets/app_audio_button.dart`
- `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`

Re-derive only generic visual or interaction behavior. Do not copy phrase,
practice, completion, activation-frame, or Garden-growth semantics.
