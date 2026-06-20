# MOBILE V2 EXECUTION INSTRUCTIONS

These instructions apply to every file under `mobile_v2/`.

## Required Reading

Before planning or editing `mobile_v2`, read:

1. `mobile_v2/CODING_STANDARDS.md`
2. The active phase `CONTEXT`, `INTERACTION-ENGINE-CONTRACT`,
   `SCHEMATIC-DESIGN`, `UI-SPEC`, and `PLAN`
3. Any more specific nested `AGENTS.md`

For Phase 41, the exact architecture authority is
`.planning/phases/41-mobile-v2-runnable-vertical-slice/41-INTERACTION-ENGINE-CONTRACT.md`.

If a phase plan conflicts with `mobile_v2/CODING_STANDARDS.md`, stop and fix the
plan before implementation. Do not encode a known conflict in code.

## Non-Negotiable Boundaries

- Organize product code by durable feature, never by rollout order or demo order.
- Use `features/ritual_room`, never `first_micro_ritual`.
- Keep one source of live state. Do not mirror controller, notifier, view model,
  repository, or widget state.
- Use unidirectional data flow from data source to repository to presentation.
- Keep transport DTOs out of presentation. Map API responses to domain models.
- Presentation must not import mock fixtures, data-source implementations, or
  ritual-specific content constants.
- Runtime ritual content and evolving interaction state come through injected
  repository boundaries. Demo data uses mock API implementations behind the
  same contracts.
- Do not model Ritual Room as a stateless reaction lookup or fixed phrase
  player. The durable contract supports typed reaction, voice, free-text,
  future-signal, and strategy inputs. Phase 41's engine and mock repository must
  execute every channel even though its UI exposes only reaction selection.
- Hiding an input through progressive disclosure is a presentation decision.
  Rejecting, disabling, stubbing, or postponing that input in the engine because
  the current UI does not expose it is forbidden.
- Context input is not child-performance tracking. Never score, persist, or
  infer compliance, correctness, learning, or task completion.
- `mobile_v2/lib` must not import runtime code from the old `mobile/` app.
- Shared `core` code must be genuinely cross-feature. Feature-specific helpers
  stay inside their feature.
- Do not add a package, code generator, global singleton, service locator, or
  architectural layer without a demonstrated need and plan approval.

## Riverpod Authority

- Riverpod is limited to app bootstrap, `app/providers/`, and provider-focused
  tests. Feature screens and widgets receive immutable domain values and
  callbacks; they do not import Riverpod.
- `RitualRoomSessionNotifier` is the only mutable Riverpod node for Ritual Room
  product-session orchestration. Do not add a second Notifier, StateNotifier,
  controller, or ViewModel that mirrors its state.
- `ProductSnapshot` remains the complete product truth. `ConsistencyState` and
  `ReplayJournal` remain internal to `InteractionEngine`; UI state carries the
  whole snapshot and may add only transient loading, submitting, or error data.
- App composition watches `ritualRoomSessionProvider` and
  `interactionCapabilityMaskProvider`. User callbacks read the input factory
  and the sole session notifier.

## Required Quality Gates

Run the narrowest relevant checks during development, then before completion run:

```text
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart run ../tool/verify_mobile_v2_semantic_firewall.dart
dart run ../tool/verify_activation_governor_contract.dart
```

Add integration, golden, accessibility, localization, or performance checks when
the changed behavior crosses those boundaries. Never claim completion from source
inspection alone.

## Executor Behavior

- Read every file listed in a plan task's `<read_first>` before editing.
- Follow the artifact paths and dependency rules in `CODING_STANDARDS.md`.
- Prefer small immutable models, constructor injection, explicit loading/error
  states, and focused widgets.
- Add tests in a path that mirrors the production artifact.
- Treat warnings, skipped tests, analyzer ignores, and disabled quality gates as
  defects requiring an issue-linked explanation.
- Do not implement unapproved prototype details. Approved schematic and asset
  artifacts are execution inputs, not inspiration.
