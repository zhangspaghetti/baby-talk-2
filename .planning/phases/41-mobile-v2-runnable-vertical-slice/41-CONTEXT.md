# Phase 41: mobile-v2-runnable-vertical-slice - Context

**Updated:** 2026-06-19
**Status:** D.4.5 visual prototype and `shoes_on` static illustration approved

## Product Decision

Phase 41 implements one direct `Ritual Room Support` surface. It does not
implement a required First Entry screen, Today Orientation screen, lesson flow,
child-performance reaction session, ritual list, or four-screen sequence.

The surface is a thin projection of the durable Ritual Interaction Engine
defined in `41-INTERACTION-ENGINE-CONTRACT.md`. Phase 41 visibly supports
reaction selection as its primary contextual input and receives a revised
utterance from a mock API. The Phase 41 engine and mock repository must also
execute voice observation, free text, future signals, and strategy preference
when submitted programmatically. Those channels are UI-hidden, not
system-disabled.

The product model is:

```text
Ritual Room = real family scene
  + approved caregiver-child line illustration
  + anchor phrase
  + action / TPR cues
  + evolving interaction context
  + current complete caregiver utterance
```

The supported fixture is `shoes_on_room_v1`:

| Field | Value |
|---|---|
| Room | `出门小声音` |
| Routine | `出门穿鞋` |
| Title / anchor phrase | `Shoes on.` |
| Chinese helper | `穿鞋啦。` |
| Illustration | approved static `shoes_on` caregiver-child line illustration |
| Exit | `先这样就好` |

Selecting a ritual from a future Ritual List should open Room Support directly,
like selecting a song opens its playback surface. Ritual List is not Phase 41
scope.

Memory Lens is optional and may appear only after quiet exit. Phase 41 does not
implement production memory tracking, child performance tracking, or Garden
state transitions.

## Approved D.4.5 Visual Decision

D.4.3 established the warm, action-bound, non-lesson visual language and D.4.4
provided the first refinement baseline. Both are historical. D.4.5 is the
approved execution reference:

`assets/prototypes/phase41-d4-5-interaction-engine.png`

D.4.5 rules:

- four panels show states of one screen, never a four-page flow
- portrait Flutter/Material geometry at 390x844
- warm paper background and parent-first tone
- compact side-by-side identity header using about 22-26% of the viewport
- approved parent-child line illustration, never a photo or classroom cartoon
- stable `Shoes on.` identity across every interaction revision
- exactly one current complete caregiver utterance as the dominant body focus
- exactly one small action / TPR timing cue, not a list or lesson sequence
- one clear 48x48-min `听一遍` play/pause affordance
- two text-only neutral reaction choices inline and more choices in a half-height
  Material bottom sheet
- submitting preserves the last usable utterance and adds only a small inline
  pending indicator
- revised context and wording replace the previous snapshot in place
- no microphone, visible free-text input, future-signal control, or strategy tray
- no task-like filled CTA, progress, numbered steps, checklist, score, streak,
  reward, badge, Garden, leaf, or growth imagery

The ready-state bootstrap example is `Let's put your shoes on.` / `我们来穿鞋吧。`
with action cue `拿起鞋时`. The revised example for neutral context `还不想穿` is
`You don't want your shoes on yet.` / `你现在还不想穿鞋。`. These values come
through the mock API; presentation code does not own them.

Voice transcript, free-text, future-signal, and strategy-preference inputs are
not visible in D.4.5, but every normalized channel is executable through the
Phase 41 engine contract.

## Content And Data Contract

All ritual-specific content comes from a backend-shaped API boundary. It must
not be hardcoded in widgets, controllers, routes, app composition, or themes.

Required flow:

```text
assets/fixtures/ritual_rooms/shoes_on.json
  -> MockRitualContentApi -> RitualRoomRepository -> RitualRoomContent
  -> MockRitualInteractionApi -> RitualInteractionRepository
     -> RitualInteractionSnapshot
  -> RitualRoomController
  -> RitualRoomScreen and focused presentation widgets
```

Presentation consumes only domain models and controller state. It must not
import the JSON fixture, mock data source, mapper implementation, or transport
DTOs.

The mock response owns:

- ritual identity and room metadata
- approved illustration reference and lifecycle status
- title, context label, Chinese helper, and reassurance
- one bootstrap/current utterance suggestion and Chinese situational helper
- one current action / TPR timing cue
- reaction-sheet title and neutral context choices
- submitting-state copy
- low-pressure reaction/context options
- contextual utterance responses for at least two sequential submissions
- interaction ID, monotonic revision, accumulated context summary, and active
  strategy metadata
- audio availability and references
- quiet exit copy
- optional Memory Lens content if the optional prompt remains
- fake Context Seed, Joinability hypothesis, and Governor
  `allow_activation` evidence required by prior vNext contracts

The demo must support loading, ready, and recoverable error/retry states.
Payload-substitution tests must change a safe mock response and observe changed
rendered UI, proving the presentation layer is not the content source.

No deployed backend, credentials, production service discovery, LLM generation,
real audio service, microphone/STT acquisition adapter, visible free-text entry,
automatic signal producer, persistent child-behavior history, complete memory
tracking, Strategy Pack, Strategy Graph, Runtime Agent, transfer metrics,
bottom navigation, or multi-room organization belongs to Phase 41. The engine
still accepts normalized voice transcripts, free-text observations, typed
future signals, and strategy preferences through its stable contract.

## Artifact And Coding Authority

All executors modifying `mobile_v2/**` must read:

- `mobile_v2/AGENTS.md`
- `mobile_v2/CODING_STANDARDS.md`
- `41-INTERACTION-ENGINE-CONTRACT.md`
- `41-SCHEMATIC-DESIGN.md`
- `41-UI-SPEC.md`

The feature name is `ritual_room`. Do not use `first_micro_ritual` or class names
that encode first-run status as the durable feature identity.

The canonical feature structure is:

```text
mobile_v2/
  assets/
    fixtures/ritual_rooms/shoes_on.json
    illustrations/rituals/shoes_on/shoes_on_approved_v1.png
  lib/
    main.dart
    app/
      baby_talk_app.dart
      theme/baby_talk_theme.dart
    features/ritual_room/
      data/
        datasources/
          ritual_content_api.dart
          mock_ritual_content_api.dart
          ritual_interaction_api.dart
          mock_ritual_interaction_api.dart
        dto/
          ritual_room_response.dart
          ritual_interaction_request.dart
          ritual_interaction_response.dart
        mappers/
          ritual_room_mapper.dart
          ritual_interaction_mapper.dart
        repositories/
          ritual_room_repository_impl.dart
          ritual_interaction_repository_impl.dart
      domain/
        models/
          ritual_room_content.dart
          ritual_context_input.dart
          ritual_interaction_snapshot.dart
          ritual_utterance_suggestion.dart
        repositories/
          ritual_room_repository.dart
          ritual_interaction_repository.dart
      presentation/
        controllers/ritual_room_controller.dart
        screens/ritual_room_screen.dart
        widgets/
          ritual_identity_header.dart
          ritual_current_utterance.dart
          ritual_context_input_tray.dart
          ritual_action_cue.dart
          ritual_listen_control.dart
          ritual_submitting_indicator.dart
  test/
    features/ritual_room/
      data/
      presentation/
```

Tests mirror `lib` ownership. No broad `helpers.dart`, `utils.dart`, or
ritual-specific content literals should appear in presentation.

`mobile_v2/pubspec.yaml` must register
`assets/fixtures/ritual_rooms/` and `assets/illustrations/rituals/`. The approved static illustration now exists at the canonical workspace path and
must be registered before Phase 41 execution.

## Forbidden Product Semantics

Do not introduce:

- `下一句`, `继续下一句`, lesson progression, course directory, or curriculum
- `孩子有没有照做？`, `做对了`, `完成动作`, or child performance records
- reaction choices framed as judging, reporting, or scoring the child; neutral
  contextual observations such as `还不想穿` are allowed engine input
- completion, daily task, check-in, progress, score, streak, badge, reward,
  unlock, growth, checklist, or classroom framing
- Garden, leaf, sprout, plant, medal, trophy, star, or checkmark imagery
- photo-real shoes, doorways, or room perspective mixed with the line system
- AI, model, generation, confidence, or backend terminology in user-facing UI

## Acceptance Proof

Phase 41 execution is accepted only when:

- the app starts on direct Ritual Room Support
- loading, ready, error/retry, long-text wrapping, playback semantics, and
  payload substitution are tested
- reaction submission covers submitting, revised-snapshot, and retry behavior
- every input variant advances a valid interaction snapshot
- sequential mixed-channel inputs prove monotonic revision, accumulated context,
  strategy evolution, and changing response state
- the first viewport visibly prioritizes the current speakable utterance
- all ritual-specific content and contextual responses are supplied through the
  mock API/repository path
- accessibility smoke checks cover semantic labels and 48x48 touch targets
- Phase 39 semantic firewall passes
- Phase 40 Activation Governor / Garden Memory verifier passes

## Canonical References

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md`
- `.planning/phases/40-activation-governor-garden-memory/40-SPEC.md`
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- `DESIGN.md`
- `mobile_v2/AGENTS.md`
- `mobile_v2/CODING_STANDARDS.md`
- `41-INTERACTION-ENGINE-CONTRACT.md`
- `tool/verify_mobile_v2_semantic_firewall.dart`
- `tool/verify_activation_governor_contract.dart`

Old `mobile/` theme and audio widgets are reference-only. They must not be
imported into `mobile_v2/lib`.
