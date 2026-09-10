# BabyTalk 2

Shared language for custom-scene generated care content and its M2 delivery boundary.

## Language

**M2 Closure Gate**:
Non-transferable set of implementation, recovery, safety, Android generated-flow UAT, and actual TalkBack conditions required before issue #28 can close. M3 work cannot satisfy or replace any unmet condition without an approved scope supersession.
_Avoid_: implementation complete, release ready

**Complete Generated Bundle**:
One scene-specific care-content unit containing one starter and five reaction-matched support utterances, returned together by generation or repair. Fixed support text is a test-fixture construct, never production generated content.
_Avoid_: starter bundle, fixed support bundle

**Bundle Activation**:
State in which all six utterances passed final deterministic validation, the complete bundle received an application-computed passing Judge verdict, and valid activation provenance was recorded. A terminal violation rejects the bundle without Repair or Judge; a repairable violation requires complete-bundle Repair and revalidation before activation remains possible.
_Avoid_: starter-only validation, partial activation

**Generated Output Violation Policy**:
Approved classification of deterministic output violations into terminal and repairable outcomes. Terminal codes reject without Repair or Judge; repairable codes require complete-bundle Repair, final validation, complete-bundle Judge, and an application-computed effective PASS before activation.
_Avoid_: test-defined safety semantics, implicit repairability

**Custom-scene Recovery Coordinator**:
App-level owner that discovers and restores durable custom-scene work after authentication is stable, including routing an approved handoff. Input screens render recovered state and text but do not independently initiate restoration.
_Avoid_: page-owned restore, multiple recovery owners

**Handoff Confirmation**:
Matching acknowledgement emitted only after a Care Turn destination resolves registered content and makes its starter utterance interactive. It is the sole successful-completion signal that permits a Custom-scene Recovery Coordinator to complete and remove a ready-for-handoff intent; before it, explicit user abandonment with a second confirmation can cancel the pending intent without treating handoff as successful.
_Avoid_: navigation started, `GoRouter.push()` completion, page return

**Ready-for-Handoff UI**:
Presentation state for a durable, registered handoff awaiting matching confirmation. Its only primary action reopens the existing generated content; it cannot create, submit, or register new content until confirmation or explicit user abandonment.
_Avoid_: retry generation, editable ready state

**M2 Manual UAT Evidence**:
Auditable device-test record tied to the final candidate SHA and APK identity for every required generated-flow, recovery, audio, and TalkBack case. A case passes only through recorded human execution with an actual passing result and closed linked defects.
_Avoid_: evidence-file presence, automated test substitute, inferred accessibility pass

**Authentic Generated-flow UAT**:
Manual Android test of a scene-matched Complete Generated Bundle returned through the production backend endpoint and formal provider path. Fake providers, fixtures, mocks, static bundles, seeded phrases, and prerecorded or test audio cannot establish its pass.
_Avoid_: simulated generated-flow UAT, provider adapter pass

**Generated Utterance**:
Independently valid member of a Complete Generated Bundle with its own phrase, pronunciation, TPR, delivery, difficulty, order, role, reaction, and provenance. A starter has no reaction; each reaction support has exactly one canonical reaction.
_Avoid_: inherited support fields, starter-labelled support

**Provider Provenance**:
Origin metadata for a Generated Utterance, separate from its role and reaction, identifying whether it was provider-generated or provider-repaired and the applicable provider/model/attempt. Fixture provenance is never valid for production generated content.
_Avoid_: source-as-branch, `source = starter`

**Invalid Legacy Bundle**:
Previously stored generated content that cannot prove compliance with the current Complete Generated Bundle contract and activation provenance. It is unavailable for handoff, Care Turn, audio, or reactions and can only lead to explicit user re-preparation.
_Avoid_: repaired legacy bundle, inferred migration

**Legacy Bundle Quarantine**:
Atomic transition that marks an Invalid Legacy Bundle `invalid` and `unavailable` before any later safe, account-scoped purge. It records only version, reason code, timing, count, and irreversible fingerprint metadata.
_Avoid_: immediate best-effort deletion, legacy archive
