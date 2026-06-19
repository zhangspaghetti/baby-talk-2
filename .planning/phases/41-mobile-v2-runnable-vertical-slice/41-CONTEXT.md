# Phase 41: mobile-v2-runnable-vertical-slice - Context

**Updated:** 2026-06-19
**Status:** Visual prototype gate; Interaction Engine single-screen states pending approval

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

## Historical D.4.3 Visual Decision

D.4.3 established the action-bound, non-lesson visual language. It is no longer
the complete interaction model. D.4.4 first image is the approved refinement
baseline, while the next single-screen multi-state prototype must add
context-input and in-place utterance-update states before execution approval.

The supplied music-list screenshot is an information-hierarchy reference only:
a compact identity area above a large practical content area. Phase 41 does not
copy its dark theme, album art, social metrics, playlist controls, or music
product semantics.

D.4.3 rules:

- portrait Flutter/Material layout at 390x844
- warm paper background and parent-first tone
- approved parent-child line illustration, never a photo or classroom cartoon
- identity header uses about 22-26% of the viewport
- header contains only `Shoes on.`, `出门穿鞋`, and `穿鞋啦。`
- body heading is `现在可以这样说`
- play-all label is `连起来听`
- action-bound talk sheet occupies most of the viewport
- first English utterance is the first strong visual focus
- no cards for each action moment and no equal lesson-row treatment
- no progress bar, numbered steps, checklist, score, streak, reward, badge, or
  growth imagery

The three action moments are:

| Cue | Minimum utterance | Optional continuation | Chinese action helper |
|---|---|---|---|
| `拿起鞋时` | `Let's put your shoes on.` | none | `拿起鞋，就说这一句。` |
| `穿第一只时` | `Let's put this shoe on first.` | `Now let's put the other one on.` | `第一只穿好，再接第二句。` |
| `穿好后` | `Your shoes are on.` | `All done. Let's go.` | `穿好后，顺口收尾。` |

Long English content uses authored semantic line breaks. One minimum utterance
is visually emphasized; optional continuations are quieter. Short fragments such
as `One shoe.` or `Tap tap.` may exist as secondary ritual grammar, but the UI
must not expect a parent who lacks speaking confidence to expand fragments into
natural sentences.

Playback rules:

- `连起来听` and each action moment have distinct hierarchy
- controls use a minimum 48x48 touch target
- the utterance text is also tappable
- playing state switches play to pause and may highlight the current utterance
- the Phase 41 visible UI has no waveform recording or microphone because those
  channels are not yet executable; the engine contract still reserves them
- no playback progress bar, score, child compliance, or performance capture

Reassurance is:

`不用每句都说，跟着当下的动作说一句就够了。`

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
- body heading and play-all label
- ordered action moments
- minimum utterances and optional continuations
- Chinese action helpers
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
          ritual_action_beat.dart
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
          ritual_action_beat_list.dart
          ritual_listen_control.dart
  test/
    features/ritual_room/
      data/
      presentation/
```

Tests mirror `lib` ownership. No broad `helpers.dart`, `utils.dart`, or
ritual-specific content literals should appear in presentation.

`mobile_v2/pubspec.yaml` must register
`assets/fixtures/ritual_rooms/` and `assets/illustrations/rituals/`. The
approved static illustration is generated and copied into the workspace only
after prototype approval, before Phase 41 execution.

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
