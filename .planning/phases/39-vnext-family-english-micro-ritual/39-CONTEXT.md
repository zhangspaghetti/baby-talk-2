# Phase 39: vnext-family-english-micro-ritual - Context

**Gathered:** 2026-06-15T07:36:14.4080395+08:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 39 locks the implementation-facing vNext supersession context for the mobile product reset. Baby Talk vNext starts from a greenfield Family English Micro-ritual contract and explicitly replaces old phrase/activity/completion/streak/garden-growth semantics. The active implementation direction is a separate `mobile_v2/` app/package, while old `mobile/` remains a frozen deprecated reference.

</domain>

<spec_lock>
## Requirements (locked via SPEC.md)

**8 requirements are locked.** See `39-SPEC.md` for full requirements, boundaries, and acceptance criteria.

Downstream agents MUST read `39-SPEC.md` before planning or implementing. Requirements are not duplicated here.

**In scope (from SPEC.md):**
- Phase 39 SPEC for vNext product thesis, non-goals, and first-principles unit.
- Explicit replacement of old Phrase/Activity/completion/streak/garden-growth product semantics with Family English Micro-ritual.
- WHAT-level surface boundaries for Home, Practice, Onboarding, and Garden.
- Supersession Matrix covering old design docs, old code semantics, old UI assumptions, deferred areas, and reusable infrastructure.
- Phase 40/41 deferral boundaries.

**Out of scope (from SPEC.md):**
- New directory/module structure was originally deferred to discuss/plan; this discussion now locks `mobile_v2/` as the implementation boundary.
- Rewrite steps, migration order, or compatibility adapter design.
- UI layout, components, navigation, route names, visual hierarchy, copy finalization, or state management details beyond the high-level surface order below.
- Activation Governor algorithms, active capacity enforcement, Garden Memory transition mechanics, or parent-confirmation UI - Phase 40.
- Primitive Library implementation, Strategy Graph schema, Strategy Pack schema, Runtime Agent payloads, and metrics instrumentation - Phase 41.
- Backend/mobile/admin implementation work.
- Database schema changes or API contracts.

</spec_lock>

<decisions>
## Implementation Decisions

### Greenfield Mobile Boundary
- **D-01:** vNext mobile implementation starts as an independent `mobile_v2/` app/package.
- **D-02:** Do not implement vNext by adding modules under old `mobile/lib/features/practice`, `mobile/lib/features/onboarding`, `mobile/lib/features/garden`, or by replacing old meanings surface by surface.
- **D-03:** Old `mobile/` is a frozen deprecated reference: readable, useful for selective copying, but not a legacy compatibility target.
- **D-04:** `mobile_v2/` runtime/product paths must not directly import old `mobile/` domain, data, or presentation models. Any copied code must be semantically re-derived inside `mobile_v2/`.

### Surface Rewrite Order
- **D-05:** Implement the vertical slice in this order: first micro-ritual onboarding -> Home current-moment orientation -> Practice micro-ritual support -> Garden memory placeholder/boundary.
- **D-06:** Onboarding must prove low-pressure entry into a first candidate micro-ritual. It must not be choosing an activity/path, completing a fixed phrase set, or seeding `starterPhraseId` as product truth.
- **D-07:** Home must orient the current family moment and gentle ritual. It must not use "next incomplete practice" logic.
- **D-08:** Practice must help one micro-ritual become speakable in routine. It must not track phrase completion or treat a child response as required success.
- **D-09:** Garden in Phase 39 implementation remains a non-scoring memory boundary/placeholder only. Full Garden Memory state transitions and parent-confirmation mechanics belong to Phase 40.

### Semantic Firewall
- **D-10:** Use a hard semantic firewall for `mobile_v2/lib` runtime/product paths.
- **D-11:** Banned old semantics in `mobile_v2/lib` runtime/product paths include: `phraseId`, `activityId`, `completedPhrase`, `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, `currentStreakDays`, `streak`, old `GardenGrowth`, phrase completion as progress, and activity/path completion as success.
- **D-12:** Allow old terms only in explicit reference/quarantine locations, such as `mobile_v2/reference_assets/`, `mobile_v2/legacy_reference/`, docs, verifier allowlists, migration notes, or test fixtures that are not runtime product truth.
- **D-13:** Quarantine/reference exceptions must not feed vNext UI, state, repository, or domain models as real product truth.

### Reuse Policy
- **D-14:** Reusable as reference or copy-and-rederive material: warm visual tone, design tokens, low-pressure onboarding/copy style, audio playback, recording, TTS, pronunciation-button interaction patterns, existing English material as raw fixedSound/example-opener source, auth, consent, event sourcing, gateway, Helm, Flyway, CI, and testing/smoke-verifier patterns.
- **D-15:** Not reusable as vNext semantics: phrase catalog as product truth, activity/path progression, phrase completion, streak, old Garden growth/fertilizer/blooming, "next incomplete" Home logic, and `starterPhraseId` as onboarding truth.
- **D-16:** "素材可以搬运，意义必须重建" is the controlling rule: assets may move only after their product meaning is rebuilt around Family English Micro-rituals.

### Proof Requirements
- **D-17:** Downstream work must produce proof stronger than docs-only.
- **D-18:** Required proof includes a `mobile_v2` semantic firewall verifier, grep/import guard, banned-term scan with allowlist, targeted unit/widget tests, and docs supersession proof.
- **D-19:** Import guard must prove `mobile_v2/` does not import old `mobile/` domain/data/presentation models.
- **D-20:** Banned-term verifier must scan `mobile_v2/lib` runtime paths and allow old terms only in explicit quarantine/reference/docs/test-fixture paths.
- **D-21:** Targeted tests must prove first micro-ritual onboarding, Home orientation, and Practice support do not depend on phrase completion, streak, or old Garden growth.
- **D-22:** Docs supersession proof must explain how every reused asset avoids carrying old product semantics.

### the agent's Discretion
No open "you decide" areas were left in this discussion. Planner/executor discretion remains only for technical organization inside `mobile_v2/`, concrete UI layout, state management details, and test implementation details, all constrained by the decisions above and by `39-SPEC.md`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Lock
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md` — locked requirements, supersession matrix, surface boundaries, in/out scope, and pass/fail rules.
- `.planning/ROADMAP.md` — M010 phase ordering and Phase 39/40/41 handoff boundaries.
- `.planning/REQUIREMENTS.md` — active R058/R059/R060 requirements and downstream R063-R066 handoffs.
- `.planning/STATE.md` — M010 restart context; old M010 phases 39-41 were discarded.

### vNext Product Source
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` — canonical vNext thesis: Family English Micro-ritual, Context Seed/Joinability, open exploration, conservative activation, Garden Memory, and parent-confirmed transfer.
- `.planning/intel/decisions.md` — supplemental activation-governor decision intel; does not override `39-SPEC.md`.
- `.planning/intel/context.md` — supplemental design/product context, including Warm Paper Kindness and Family English Garden notes; does not override `39-SPEC.md`.

### Reference-Only Old Code
- `mobile/lib/features/practice/domain/models/practice_phrase.dart` — old phrase model; deprecated reference only.
- `mobile/lib/features/practice/domain/models/practice_activity_catalog.dart` — old activity/completion summary model; deprecated reference only.
- `mobile/lib/features/practice/domain/models/interaction_event_payload.dart` — old event payload with `spaceId`/`activityId`/`phraseId`; event-sourcing pattern may be re-derived, payload semantics may not.
- `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart` — old onboarding truth with `starterPhraseId`; deprecated reference only.
- `mobile/lib/features/practice/data/repositories/garden_growth_repository.dart` — old phrase-completion/streak Garden projection; deprecated reference only.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenSnapshotService.java` — backend old Garden streak/milestone projection; deprecated product semantics, infrastructure/reference only.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mobile/lib/app/theme/app_theme.dart` and `mobile/lib/app/widgets/*`: warm visual tone, `BabyTalkColors`, `warmShadowSm/Md/Lg`, shared surface/card/audio/empty-state patterns may be copied or re-derived into `mobile_v2/`.
- `mobile/lib/features/onboarding/presentation/*`: onboarding warmth and low-pressure style may inform `mobile_v2/`, but scene/path/starter-phrase truth must not carry over.
- `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`, `activation_frame.dart`, audio buttons, and related interaction widgets: interaction patterns may inform fixedSound/example opener experiences, but phrase completion semantics are forbidden.
- Auth, consent, append-only event sourcing, gateway, Helm, Flyway, CI, and smoke verifier patterns remain reusable infrastructure behind a product-semantic firewall.

### Established Patterns
- Existing mobile uses Flutter/Riverpod/Freezed-style domain models and feature directories. `mobile_v2/` may reuse the stack and testing habits, but should use new vNext domain names and paths.
- Existing product semantics are deeply embedded across models, UI, repositories, tests, and generated code. This is the reason for the hard `mobile_v2/` boundary.
- Existing Garden projections derive growth, milestones, and streaks from phrase events. vNext must not reuse that projection as product truth.

### Integration Points
- `mobile_v2/` should be planned as a separate app/package under the monorepo, not as an in-place rewrite under `mobile/`.
- Any future backend/API integration must respect the same semantic firewall: infrastructure can be reused, but phrase/activity/completion payload truth must be re-derived for micro-rituals.
- Verification should run from repo-root scripts where practical and should make the path boundary machine-checkable.

</code_context>

<specifics>
## Specific Ideas

- Preferred vertical slice: `first micro-ritual onboarding -> Home shows current gentle ritual -> Practice supports speaking it -> Garden only shows non-scoring memory boundary/placeholder`.
- Hard path boundary: `mobile_v2/` is active vNext; `mobile/` is deprecated reference.
- Planner input: old `mobile/` remains reference-only until a later explicit cleanup phase decides whether to delete it.
- Product tone: parent-facing, warm, non-testing, no shame, no streaks, no completion pressure.

</specifics>

<deferred>
## Deferred Ideas

- Deleting or cleaning up old `mobile/` belongs to a later explicit cleanup phase.
- Activation Governor algorithms, active capacity enforcement, Garden Memory transition mechanics, and parent-confirmation UI belong to Phase 40.
- Primitive Library, Strategy Graph, Strategy Pack schema, Runtime Agent payloads, and transfer metrics belong to Phase 41.

</deferred>

---

*Phase: 39-vnext-family-english-micro-ritual*
*Context gathered: 2026-06-15T07:36:14.4080395+08:00*
