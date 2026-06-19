# Mobile V2 Flutter Coding Standards

**Status:** mandatory
**Scope:** the complete `mobile_v2` application, not only Phase 41
**Updated:** 2026-06-18
**Audience:** planners, executors, reviewers, and maintainers

## 1. Authority And Intent

This document is the long-lived engineering standard for the Baby Talk vNext
Flutter application. It controls architecture, artifact placement, state and data
flow, UI implementation, quality attributes, testing, delivery, and maintenance.

The standard is based on:

- Flutter's official architecture recommendations
- Effective Dart
- Flutter repository engineering and style guidance
- Flutter's official testing, accessibility, internationalization, and
  performance guidance
- Baby Talk vNext product and semantic boundaries

It deliberately does not copy the old `mobile/` structure. The old application is
reference material only and contains known problems such as duplicate state truth,
large overloaded files, and cross-feature imports.

The words **must**, **must not**, **should**, and **may** have their normal RFC-style
meaning. A plan may deviate from a **should** with a written rationale. It may not
silently deviate from a **must**.

## 2. Engineering Principles

1. **Optimize for the reader.** Code is read more often than it is written.
2. **One source of truth.** Never duplicate live state between layers or objects.
3. **Unidirectional data flow.** Data flows toward UI; user intent flows back
   through explicit commands.
4. **Separate concerns by responsibility.** UI, application state, domain rules,
   data access, transport, and platform integration have different owners.
5. **Feature-first organization.** Durable product concepts own their artifacts.
6. **Explicit dependencies.** Constructor injection is the default. Hidden global
   state and service locators are forbidden.
7. **Immutable boundaries.** API DTOs, domain models, and presentation state are
   immutable snapshots.
8. **Model failure as a first-class state.** Loading, empty, recoverable error,
   retry, and unavailable states are designed and tested.
9. **Build only proven abstractions.** Do not create layers or frameworks for
   hypothetical future reuse.
10. **Quality attributes are product behavior.** Accessibility, localization,
    privacy, performance, lifecycle safety, and observability are not cleanup work.

## 3. Repository Artifact Organization

The target package structure is:

```text
mobile_v2/
├── AGENTS.md
├── CODING_STANDARDS.md
├── README.md
├── analysis_options.yaml
├── l10n.yaml
├── pubspec.yaml
├── assets/
│   ├── audio/
│   │   └── rituals/<ritual_id>/
│   ├── fixtures/
│   │   └── ritual_rooms/
│   ├── fonts/
│   ├── icons/
│   └── illustrations/
│       └── rituals/<ritual_id>/
├── lib/
│   ├── main.dart
│   ├── main_development.dart
│   ├── main_staging.dart
│   ├── main_production.dart
│   ├── app/
│   │   ├── bootstrap/
│   │   ├── config/
│   │   ├── di/
│   │   ├── localization/
│   │   ├── navigation/
│   │   ├── observability/
│   │   ├── theme/
│   │   └── baby_talk_app.dart
│   ├── core/
│   │   ├── error/
│   │   ├── network/
│   │   ├── storage/
│   │   ├── ui/
│   │   └── utils/
│   └── features/
│       └── <feature_name>/
│           ├── data/
│           │   ├── datasources/
│           │   ├── dto/
│           │   ├── mappers/
│           │   └── repositories/
│           ├── domain/
│           │   ├── models/
│           │   ├── repositories/
│           │   ├── services/
│           │   └── use_cases/
│           └── presentation/
│               ├── controllers/
│               ├── screens/
│               └── widgets/
├── test/
│   ├── app/
│   ├── core/
│   ├── features/
│   ├── fixtures/
│   └── helpers/
├── integration_test/
├── tool/
└── test_driver/
```

Not every directory must exist immediately. Create a directory only when it owns
at least one real artifact. Empty architecture scaffolding is forbidden.

### 3.1 Durable Names

- Feature names describe stable product capabilities: `ritual_room`,
  `ritual_library`, `household`, or `account`.
- Never name features after sequence or rollout position: `first_*`, `phase_41`,
  `v1_screen`, `new_flow`, or `demo_feature`.
- File and directory names use `lowercase_with_underscores`.
- Types use `UpperCamelCase`; members use `lowerCamelCase`.
- Names describe responsibility, not implementation trivia.

### 3.2 Feature Ownership

- Feature-specific models, errors, UI helpers, and data adapters stay in the
  feature.
- `core/` contains only behavior used by multiple features with the same meaning.
- Features must not import another feature's private data or presentation layer.
- Cross-feature collaboration happens through a public domain/application contract
  or an app-level coordinator.
- `app/` composes features; it does not absorb their business logic.

### 3.3 Test Mirroring

Tests mirror production paths:

```text
lib/features/ritual_room/data/mappers/ritual_room_mapper.dart
test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart

lib/features/ritual_room/presentation/screens/ritual_room_screen.dart
test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
```

Shared test builders and fakes live under `test/helpers/` or
`test/fixtures/`. Production code must never import from `test/`.

## 4. Layer Responsibilities And Dependency Direction

The default feature dependency direction is:

```text
presentation -> domain <- data
app/bootstrap -> feature public contracts
```

The runtime data path is:

```text
remote or mock data source
  -> transport DTO
  -> mapper
  -> repository implementation
  -> domain model
  -> controller/view model state
  -> screen/widgets
```

User intent returns through:

```text
widget callback
  -> controller command
  -> repository/domain operation
  -> new immutable state
```

### 4.1 Presentation

Presentation owns:

- screens and reusable feature widgets
- ephemeral UI state
- controller/view-model state
- mapping domain state to view state
- user intent callbacks and commands
- semantics, focus, responsive layout, and interaction feedback

Presentation must not:

- parse JSON
- know HTTP status codes or transport DTOs
- import mock payloads or concrete data sources
- contain ritual-specific backend content constants
- perform storage, network, analytics transport, or platform-channel work
- hold a second copy of repository/domain live state

Widgets should receive the smallest useful immutable input and callbacks. Split a
widget when it owns a coherent visual/interaction responsibility or rebuild
boundary, not merely to reduce line count.

### 4.2 Domain

Domain owns:

- product concepts and invariants
- immutable models
- repository interfaces
- pure policies and calculations
- use cases only when orchestration is complex or reused

Domain must not import Flutter widgets, HTTP clients, JSON serializers, storage
drivers, platform plugins, or concrete repository implementations.

Do not add a domain use case that merely forwards one repository method. Use cases
earn their existence by coordinating rules, multiple repositories, authorization,
or reusable workflow logic.

### 4.3 Data

Data owns:

- remote, local, and mock data sources
- transport DTOs and serialization
- repository implementations
- DTO-to-domain mappers
- caching and freshness policies
- normalization of external failures into app errors

Each external system has a data-source boundary. A mock API implements the same
boundary as the future remote adapter; it is not a bag of constants imported by
the UI.

### 4.4 Repository Rule

Repositories are the domain-facing source of application data. They hide whether
data came from a backend API, fixture, cache, database, or platform service.

- Repository interfaces live in `domain/repositories/`.
- Implementations live in `data/repositories/`.
- Repositories return domain models or typed app failures, never raw JSON or
  transport DTOs.
- Cache/network merge policy belongs in the repository implementation.
- A repository must not become a generic grab bag. Split by product aggregate or
  coherent data responsibility.

## 5. State Management

### 5.1 Single State Owner

Every piece of live state has one owner. Derived values are calculated from that
state, not stored again.

Forbidden:

- ViewModel plus Notifier storing the same state
- controller state copied into widget fields
- repository response copied into mutable singleton state
- separate loading booleans that can contradict a state union

### 5.2 State Shape

Represent meaningful asynchronous states explicitly:

```text
initial
loading
ready(data)
empty
recoverableError(problem)
unavailable(problem)
```

Avoid unrelated booleans such as `isLoading`, `hasError`, and `hasData` that allow
impossible combinations.

### 5.3 State Technology

- Prefer Flutter SDK primitives for isolated, small state.
- Adopt Riverpod when state is shared, lifecycle-aware, dependency-rich, or needs
  testable application-wide composition.
- Do not add Riverpod, Freezed, or code generation only to satisfy a template.
- Once a state technology is selected for a feature, do not introduce a parallel
  owner for the same state.
- Controllers must dispose resources and must not update state after disposal.

## 6. Models, DTOs, And Serialization

- Transport DTOs mirror the backend contract and may contain nullable or
  transport-specific fields.
- Domain models express valid product concepts and should make invalid states hard
  to represent.
- Presentation models exist only when the screen needs a materially different
  shape from the domain model.
- Map at boundaries. Do not leak DTOs into widgets.
- Models are immutable; collections exposed by models are not externally mutable.
- Use exhaustive enums or sealed types for bounded lifecycle states.
- JSON parsing validates required fields and produces typed failures with useful
  diagnostics.
- Unknown enum values must have an explicit compatibility policy.
- Do not use `dynamic` to bypass contract design.
- Code generation is allowed when it removes meaningful serialization/equality
  boilerplate and its build cost is justified.

## 7. Dependency Injection And Composition

- Constructor injection is the default.
- Object graph creation belongs in `app/bootstrap/` or `app/di/`.
- Widgets do not instantiate repositories, network clients, databases, or concrete
  mock services.
- Global mutable singletons and service locators are forbidden.
- Environment selection happens at composition time.
- Tests replace dependencies with fakes through public constructors/providers.
- Dependency lifetime must be explicit: app, session, feature, route, or widget.

## 8. Backend, Networking, And API Contracts

- All backend access goes through typed data sources and repositories.
- Configure base URL, timeouts, certificates, and logging outside feature widgets.
- Never log authorization headers, tokens, household identifiers, child data,
  audio content, or raw sensitive payloads.
- Define request cancellation and stale-response behavior for route disposal and
  repeated requests.
- Retries must be bounded, idempotency-aware, observable, and user-safe.
- Convert transport failures into typed app problems at the data boundary.
- Error UI should explain recovery, not expose stack traces or backend internals.
- Pagination, cache validation, and optimistic updates require explicit contracts.
- API changes must include DTO, mapper, repository, fixture, and contract-test
  updates.
- Demo mode uses an asynchronous mock implementation behind the same boundary.
  Presentation code must not know whether the source is mock or remote.

## 9. Local Storage, Cache, And Offline Behavior

- Storage adapters live under `core/storage/` or the owning feature's data layer.
- Persist the minimum necessary data.
- Sensitive values use platform secure storage, never plain preferences.
- Every cache defines key, scope, freshness, invalidation, size limit, and schema
  migration behavior.
- Cached transport DTOs are mapped before reaching the domain/presentation layers.
- Offline UI distinguishes cached data, unavailable actions, and recoverable sync
  failures.
- Destructive migrations require explicit product and rollback review.

## 10. Navigation

- Use declarative routing for application navigation; `go_router` is the default
  when routing complexity requires it.
- Route names and paths express product destinations, not implementation classes.
- Route parameters are validated at the boundary.
- Deep links, restoration, authentication redirects, and unknown routes have
  explicit behavior.
- Feature screens do not perform hidden global navigation.
- Back behavior, system back gestures, and interrupted flows are tested.
- A modal is not a substitute for a route when the state must be linkable or
  restorable.

## 11. UI, Design System, And Responsive Layout

- Material 3 primitives are the base unless an approved design contract says
  otherwise.
- Design tokens live under `app/theme/`; feature widgets consume semantic tokens.
- Do not scatter raw colors, radii, text styles, or spacing constants through
  screens.
- Shared widgets are promoted only after at least two genuinely equivalent uses.
- Page sections are unframed by default. Do not nest decorative cards.
- Use stable constraints for fixed-format controls and media.
- Support narrow phones, large phones, text scaling, safe areas, and keyboard
  insets without overflow or overlap.
- Use `LayoutBuilder`, constraints, and adaptive composition; do not size text from
  viewport width.
- Respect platform conventions where they improve usability.
- Empty, loading, error, and partial-data states receive the same design attention
  as ready state.

## 12. Accessibility

Accessibility is a release gate.

- Every interactive control has a meaningful semantic label and action.
- Tap targets are at least 48x48 logical pixels.
- Text and controls meet WCAG AA contrast; normal text targets at least 4.5:1.
- Do not communicate state by color alone.
- Focus order follows reading and task order.
- Screen readers must describe controls, state changes, errors, and images
  intelligibly.
- Decorative images are excluded from semantics; informative images have concise
  descriptions.
- Support text scaling to at least 2.0 for app UI. Shared foundational widgets
  should be tested toward 3.0 where practical.
- Support both left-to-right and right-to-left ambient directionality.
- Respect reduced motion and avoid motion-only meaning.
- Test important flows with Android TalkBack and iOS VoiceOver before release.
- Disabled or no-op controls must not be shipped.

## 13. Internationalization And Product Content

- User-facing app chrome is localized through Flutter localization resources.
- Do not embed translatable UI copy directly in widgets.
- Backend-owned content remains backend-owned and carries locale metadata when
  required.
- Translation keys describe meaning, not English wording.
- Support plural, gender, date, number, and locale-specific formatting through
  localization APIs.
- Layouts must tolerate longer translations and mixed Chinese/English content.
- The first supported locale is not treated as a universal fallback by accident.
- Right-to-left layout and bidirectional text are tested when those locales are
  enabled.
- Product terminology is centralized and used consistently.

## 14. Assets, Illustration, Audio, And Fonts

### 14.1 Placement

```text
assets/illustrations/rituals/<ritual_id>/<asset_name>.<ext>
assets/audio/rituals/<ritual_id>/<locale>/<asset_name>.<ext>
assets/fixtures/ritual_rooms/<fixture_name>.json
assets/icons/<semantic_name>.<ext>
assets/fonts/<family>/<file>
```

- Runtime assets must be declared in `pubspec.yaml`.
- Filenames use stable semantic IDs, not final-final-v2 naming.
- Generated assets keep provenance, prompt/version, approval state, dimensions,
  license, and checksum in an adjacent manifest when they enter production.
- Mock fixtures are data-source inputs, not production truth imported by widgets.
- Reference-only material stays outside runtime asset paths.

### 14.2 Image And Illustration Rules

- Store an asset at the smallest resolution that remains sharp at its maximum
  rendered size and target device pixel ratios.
- Define aspect ratio and fit behavior; do not depend on accidental image
  dimensions.
- Precache only assets needed immediately.
- Large image decoding and transformations must not block UI work.
- Illustration lifecycle and approval are backend/asset-pipeline concerns; UI
  consumes approved asset references.

### 14.3 Audio Rules

- Audio controls expose play, pause, loading, unavailable, and error semantics.
- Audio focus and interruption behavior must be defined.
- Dispose players and subscriptions.
- Do not preload unbounded audio collections.
- Playback analytics must not capture child audio or private household content.

## 15. Security, Privacy, And Child Safety

- Collect and retain the minimum data required for the feature.
- Treat child, household, voice, routine, and behavioral data as sensitive.
- Never commit secrets, tokens, production endpoints, private keys, or credentials.
- Environment secrets are injected by the deployment platform, not Dart constants.
- Validate and constrain all external URIs, files, deep links, and backend content.
- Do not render backend HTML or executable content.
- Avoid sensitive values in logs, crash reports, analytics, screenshots, and test
  fixtures.
- Permission requests are contextual, just-in-time, and explainable.
- Denied permissions have a functional fallback.
- Security-relevant storage, authentication, and deletion behavior require
  integration tests.
- Child behavior must not be inferred, scored, diagnosed, or tracked without an
  explicitly approved product and privacy contract.

## 16. Errors, Diagnostics, And Observability

- User-facing errors are calm, actionable, and localizable.
- Developer diagnostics include operation, safe identifiers, cause chain, and
  correlation context without sensitive payloads.
- Do not swallow exceptions.
- Catch expected exception types with `on`; use `rethrow` when preserving the
  original failure.
- Define a top-level Flutter/framework error reporting boundary.
- Analytics events describe product intent and outcome, not widget implementation.
- Event schemas are versioned and reviewed.
- Logs use levels and structured fields.
- Crash and performance monitoring are environment-aware and disabled or sanitized
  in tests.

## 17. Performance

- Keep `build()` pure and free of network, storage, parsing, and expensive repeated
  work.
- Split large widgets by responsibility and rebuild behavior.
- Prefer `const` constructors and stable immutable inputs.
- Use lazy builders for long or unbounded lists.
- Avoid unnecessary `Opacity`, clipping, `saveLayer`, intrinsic layout, and nested
  scroll views.
- Decode images near their display size.
- Move CPU-heavy parsing or transformation off the UI isolate when profiling
  proves it necessary.
- Cancel work that is no longer relevant.
- Measure in profile mode on representative devices; debug-mode timing is not
  release evidence.
- Performance-sensitive changes include a baseline, measurement method, and
  regression threshold.
- Memory, subscriptions, controllers, focus nodes, animation controllers, and
  platform resources must be disposed.

## 18. Platform Integration And Lifecycle

- Platform channels and plugins are wrapped behind typed app interfaces.
- Feature UI does not call platform channels directly.
- Handle pause, resume, detach, interruption, process recreation, and state
  restoration where behavior matters.
- Platform-specific behavior is isolated and tested per platform.
- Plugin selection includes maintenance, license, platform coverage, privacy,
  binary size, accessibility, and failure-mode review.
- Native permission dialogs and platform views require device-level integration
  testing.

## 19. Testing Standard

A well-tested feature has many unit and widget tests plus enough integration tests
to cover critical user journeys.

### 19.1 Unit Tests

Required for:

- mappers and serializers
- repositories and cache policy
- controllers/view models
- domain policies and use cases
- error normalization
- configuration parsing

Use fakes by default. Mock call-order assertions are reserved for behavior where
interaction order is the contract.

### 19.2 Widget Tests

Required for:

- ready, loading, empty, and error/retry states
- user interaction and callbacks
- payload substitution
- semantics and focus
- text scaling and narrow layouts
- localization-sensitive rendering
- route-level dependency composition

Avoid tests that only assert exact production copy when the goal is to prove data
ownership. Substitute a second safe payload and verify the UI changes.

### 19.3 Golden Tests

Use golden tests for stable visual contracts, not every widget. Cover approved
screens, critical components, multiple text scales, and representative viewport
sizes. A golden update requires visual review.

### 19.4 Integration Tests

Cover:

- critical end-to-end journeys
- routing and dependency injection
- persistence and network adapter integration
- authentication and permission behavior
- audio/platform lifecycle where applicable
- performance traces for known hot paths

### 19.5 Test Hygiene

- Tests are deterministic and independent.
- No arbitrary sleeps or timer-based synchronization.
- Skipped tests require an issue link and owner context.
- A bug fix starts with a failing regression test when feasible.
- Tests do not call production services.
- Fixtures contain no real personal or household data.

## 20. Dart Style And API Design

- Follow Effective Dart and `dart format`.
- Use braces for control flow.
- Prefer `final`; use `const` where it improves correctness and reuse.
- Public APIs have explicit parameter and return types.
- Avoid `dynamic`, unnecessary `late`, positional booleans, and nullable
  collections/futures.
- Async methods that return no value use `Future<void>`.
- Prefer `async`/`await` when it makes control flow clearer.
- Public APIs receive concise `///` documentation.
- Comments explain constraints and decisions, not obvious syntax.
- Analyzer ignores require an inline reason; temporary ignores require an issue
  link.
- APIs are small, predictable, and hard to misuse.
- Getters are cheap and side-effect free.
- Expensive or effectful work uses methods/commands.
- Constructors and class members follow a consistent reader-oriented order.
- Keep files cohesive. Split when responsibilities diverge, not at an arbitrary
  line count.

## 21. Dependencies And Code Generation

- Prefer Flutter/Dart SDK capabilities and existing approved packages.
- Every new dependency requires:
  - demonstrated need
  - maintenance and publisher review
  - license review
  - platform support review
  - privacy/security review
  - size and performance consideration
  - test strategy
- Pin compatible ranges deliberately and commit the lockfile for the application.
- Do not depend on another package's `src/` internals.
- Generated files are reproducible and never hand-edited.
- Codegen commands and expected outputs are documented.
- Remove unused dependencies promptly.

## 22. Configuration, Environments, And Release

- Development, staging, and production differ through typed configuration and
  composition, not scattered conditionals.
- Build-time values are validated at startup.
- Production builds fail closed when required configuration is missing.
- Demo/mock mode is explicit and cannot accidentally ship as production.
- Release builds run formatting, analyze, unit/widget tests, integration smoke,
  semantic verifiers, asset validation, and platform build checks.
- Versioning, signing, obfuscation/symbol upload, privacy declarations, and store
  metadata are part of the release checklist.
- Rollback and compatibility behavior are defined before irreversible migrations.

## 23. CI And Review Gates

Minimum pull-request gates:

```text
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
semantic verifier suite
asset/fixture validation
platform build smoke for affected targets
```

Additional gates are triggered by change type:

| Change | Additional evidence |
|---|---|
| Screen/layout | widget tests, text-scale check, narrow viewport, visual review |
| Shared widget | semantics, RTL, 2.0+ text scale, lifecycle tests |
| API/DTO | contract fixture, mapper, repository, malformed response tests |
| Persistence | migration, rollback/compatibility, offline behavior |
| Audio/plugin | device integration, interruption, disposal |
| Performance hot path | profile trace and regression comparison |
| Security/privacy | threat review and sensitive-data log audit |

Reviewers check correctness, ownership boundaries, failure states, accessibility,
privacy, lifecycle, test quality, and product semantics before style preference.

## 24. Mobile V2 Semantic Boundaries

- Product unit: Family English Micro-ritual and Ritual Room.
- `mobile_v2/lib` must not import old `mobile/` runtime code.
- Do not reintroduce Practice, task completion, streak, score, reward, growth,
  classroom, or child-performance semantics.
- Candidate matching is not activation.
- Child non-response is valid and must not be represented as failure.
- Ritual-specific copy, phrases, action cues, illustration references, and audio
  references come from the content boundary.
- Presentation tests must prove content ownership through payload substitution.
- Reference assets and old code are quarantined and never become runtime imports.

## 25. Phase 41 Ritual Room Artifact Standard

Phase 41 uses this concrete structure:

```text
lib/features/ritual_room/
├── data/
│   ├── datasources/
│   │   ├── ritual_content_api.dart
│   │   ├── mock_ritual_content_api.dart
│   │   ├── ritual_interaction_api.dart
│   │   └── mock_ritual_interaction_api.dart
│   ├── dto/
│   │   ├── ritual_room_response.dart
│   │   ├── ritual_interaction_request.dart
│   │   └── ritual_interaction_response.dart
│   ├── mappers/
│   │   ├── ritual_room_mapper.dart
│   │   └── ritual_interaction_mapper.dart
│   └── repositories/
│       ├── ritual_room_repository_impl.dart
│       └── ritual_interaction_repository_impl.dart
├── domain/
│   ├── models/
│   │   ├── ritual_context_input.dart
│   │   ├── ritual_interaction_snapshot.dart
│   │   ├── ritual_utterance_suggestion.dart
│   │   ├── ritual_memory_prompt.dart
│   │   └── ritual_room_content.dart
│   └── repositories/
│       ├── ritual_room_repository.dart
│       └── ritual_interaction_repository.dart
└── presentation/
    ├── controllers/
    │   └── ritual_room_controller.dart
    ├── screens/
    │   ├── ritual_room_screen.dart
    │   └── ritual_memory_lens_screen.dart
    └── widgets/
        ├── ritual_action_cue.dart
        ├── ritual_context_input_tray.dart
        ├── ritual_current_utterance.dart
        ├── ritual_identity_header.dart
        ├── ritual_listen_control.dart
        ├── ritual_reassurance.dart
        └── ritual_submitting_indicator.dart
```

Phase 41's mock JSON belongs at:

```text
assets/fixtures/ritual_rooms/shoes_on.json
```

The approved static illustration will belong at:

```text
assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png
```

The feature name is `ritual_room`. `first_micro_ritual`, `FirstMicroRitualSlice`,
and equivalent rollout-order names are forbidden.

## 26. Ritual Interaction Engine Extensibility

- Treat the UI as a projection of an evolving interaction snapshot, not the
  owner of interaction truth.
- A context submission is a typed envelope. The supported durable channels are
  reaction selection, voice observation, free-text observation, future signal,
  and strategy preference.
- Phase 41's interaction API, repository, mapper, mock engine, and tests execute
  every channel. The Phase 41 UI exposes only reaction selection.
- Voice capture/STT, visible free-text entry, signal producers, and strategy
  controls are input-adapter or presentation concerns. Their absence from the
  current UI must not disable normalized engine inputs.
- Do not add nonfunctional microphone, transcript, text-entry, or strategy
  controls as placeholders.
- Do not collapse the repository into
  `Map<Reaction, String>` or equivalent stateless lookup logic.
- Every accepted input returns a new immutable snapshot with a monotonic
  revision, one primary speakable utterance, and at most one current action cue.
- Phase 41 presentation must not render a multi-utterance action list. Additional
  utterances remain engine behavior for later product decisions.
- Contract tests cover every input variant plus a mixed-channel sequence that
  proves accumulated context and strategy evolution.
- The controller dispatches typed inputs and replaces its snapshot from the
  repository result. Widgets do not synthesize strategy or context history.
- Strategy metadata is domain data. It is not displayed as AI/model/backend
  terminology and is not a child-discipline or compliance score.
- Interaction context is sensitive. Phase 41 keeps it in memory and does not
  persist raw observations, transcripts, or behavioral labels.

The controlling product contract is:

```text
.planning/phases/41-mobile-v2-runnable-vertical-slice/
  41-INTERACTION-ENGINE-CONTRACT.md
```

## 27. Sources

Verified on 2026-06-18:

- Flutter architecture recommendations:
  https://docs.flutter.dev/app-architecture/recommendations
- Effective Dart:
  https://dart.dev/effective-dart
- Flutter repository style guide:
  https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md
- Flutter testing overview:
  https://docs.flutter.dev/testing/overview
- Flutter accessibility guidance:
  https://docs.flutter.dev/ui/accessibility
- Flutter performance best practices:
  https://docs.flutter.dev/perf/best-practices
- Flutter internationalization:
  https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization
