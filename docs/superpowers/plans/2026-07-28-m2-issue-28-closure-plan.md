# #28 / M2 Closure Plan

Date: 2026-07-28  
Status: Accepted closure plan — implementation pending

This is the sole closure plan for #28. M2 is neither complete nor release-ready until every required automated gate and human UAT case passes on one final candidate SHA/APK. A `FAIL`, `BLOCKED`, or `NOT RUN` result keeps #28 open. Any reduction requires an explicit scope supersession that updates the Wayfinder, #28 acceptance criteria, release matrix, and verification document.

## Non-negotiable contracts

- A **Complete Generated Bundle** contains exactly one `starter` and one support for each canonical reaction: `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`.
- Generator and Repair each make one provider operation and return the complete typed bundle. Production cannot synthesize or append support text.
- Shared bundle fields are `spaceTitleZh`, `activityTitleZh`, and `sceneTagEn`. Every utterance independently owns its phrase, pronunciation, TPR, delivery, difficulty, display order, role, reaction, and provider provenance.
- `role` and `reaction` are independent: starter is `starter/null`; supports are `reaction_support/<canonical reaction>`. Provenance never encodes role or reaction.
- Every utterance must pass the same deterministic safety gate before activation. A terminal violation rejects the whole bundle. Repair returns a complete bundle, then all six utterances are revalidated and judged.
- `readyForHandoff` is durable. Navigation start and `GoRouter.push()` completion are not confirmation. Only a matching Care Turn acknowledgement after the starter is interactively available permits cleanup.
- Legacy content failing the current bundle/provenance contract becomes atomically `invalid/unavailable`, never inferred or template-migrated, then is purged safely.

## 1. Backend

### Typed contract and provider adapters

- [ ] Replace starter-only generator contract in `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerator.java` with a required complete-bundle return type. Remove production default `generateCareMoment()` and `fromStarter()` fallback.
- [ ] Change `CustomSceneRepairer.java` so repair input and output are complete bundles; no single-candidate repair return remains in production.
- [ ] Redesign `GeneratedCareMomentBundle.java` and `GeneratedCareUtterance.java` to enforce shared fields, one starter, five unique canonical supports, valid role/reaction matrix, independent utterance fields, display order, and provider provenance.
- [ ] Update `AgenticCustomSceneGenerator.java` and `AgenticCustomSceneRepairer.java` wire responses and prompts so a single structured provider call returns all six typed utterances. Reject missing, duplicate, unknown, or free-text reaction keys during parsing.
- [ ] Preserve provider/model/attempt provenance per utterance. Generator marks provider-generated content; Repair marks provider-repaired content without changing canonical reaction placement.
- [ ] Restrict fixed support text and fake responses to explicit fake/test fixtures only.

### Safety, repair, judge, activation, and persistence

- [ ] Refactor `CustomSceneGenerationOrchestrator.java` to process a complete bundle for initial generation and every repair attempt. Remove every production `GeneratedCareMomentBundle.fromStarter(...)` path.
- [ ] Convert each utterance into the same validator candidate used today by `CustomSceneGeneratedContentValidator`; run PII, bidi, unsafe-instruction, course/scoring, Markdown/template, TPR, delivery, field-role, language-length, and difficulty checks for all six.
- [ ] Reject the entire bundle before Judge/ACTIVE on any terminal violation. Never drop a branch, replace a branch, or partially register a bundle.
- [ ] Build repair context from full-bundle violations; after repair, revalidate all six and submit the complete bundle to Judge. Application-computed terminal violations must never be upgraded to PASS.
- [ ] Update `PracticeGeneratedContentService.java`, orchestration persistence, API DTOs, and approved-utterance rows so registration stores the strict role/reaction/provenance matrix and no support is labelled `starter`.
- [ ] Reject backend reads/writes that lack supported schema/version, complete bundle structure, or activation provenance. Do not repair old data by inference.

### Backend acceptance tests

- [ ] Extend `AgenticCustomSceneGeneratorTest.java` and `AgenticCustomSceneRepairerTest.java`: one provider call; one typed six-utterance response; strict rejection of missing/duplicate/unknown keys; Repair receives and returns complete bundles.
- [ ] Replace starter-template tests in `GeneratedCareMomentBundleTest.java` with structural, role/reaction, provenance, and independent-field contract tests.
- [ ] Extend `CustomSceneGenerationOrchestratorTest.java` with two canonical fixtures, such as shoes and bath. Assert scene-specific support and branch behavior: continue, lower pressure/choice, name feeling/reduce force, simplify/add sensory cue, safe open acknowledgement.
- [ ] Parameterize six utterance positions by each terminal class: PII, bidi control, dangerous instruction, course/scoring framing, Markdown/template, and TPR/delivery missing/swapped. Assert no register, no ACTIVE, no partial response, no fallback, and no Judge PASS.
- [ ] Test repairable violations: one complete Repair call, all six revalidated, original branch identities preserved, then Judge/activation only after application-computed PASS.
- [ ] Add a production-source static verifier/test that fails on starter-only wire responses, generator/repair single-candidate defaulting, fixed support maps, `fromStarter()` production calls, or generic-support recovery. Whitelist only clearly named fake/test fixture paths.
- [ ] Run Spring AI platform verifier, targeted tests, then `cd backend && bash mvnw clean test` on the final candidate.

## 2. Mobile

### Registry model and legacy quarantine

- [ ] Update `mobile/lib/features/custom_scene/domain/generated_care_moment.dart`, mapper, and DTO boundaries to carry role, nullable canonical reaction, per-utterance provenance, independent fields, and supported schema/version.
- [ ] Update `mobile/lib/features/practice/data/generated/generated_care_moment_local_store.dart` encode/decode format and `generated_practice_content_registry.dart` validation to fail closed before any consumer receives a bundle.
- [ ] Atomically mark incompatible records `invalid/unavailable`; prevent Care Turn, audio, reaction, Garden, Today, registry registration, and handoff consumption.
- [ ] Add account-scoped, idempotent, low-priority purge of quarantined contents and derivatives. Delete textual/derived local content before indexes, caches, and handoff references. Never call network or generation during quarantine/purge.
- [ ] When a restored handoff targets invalid content, cancel only the unusable intent, show “这条内容需要重新准备”, and require explicit user action to mint a new `clientRequestId`.
- [ ] Emit diagnostics only as reason code, schema/contract version, timestamp, count, and irreversible truncated fingerprint; never emit text, scene input, payloads, tokens, account identifiers, or device identifiers.

### Durable recovery and confirmed handoff

- [ ] Extend `CustomSceneStoredDraft` and `custom_scene_draft_store.dart` as needed to persist `readyForHandoff`, matching `generatedContentId`, and durable handoff status/intent before any navigation. Registration order is: registry success; persist ready intent; clear authentication-only continuation; request route.
- [ ] Split current `CustomSceneDraftContinuationCoordinator.cancel()` responsibilities so registration cannot erase the durable draft/intent before handoff confirmation.
- [ ] Introduce one app-level Recovery Coordinator, wired through app/root providers after authenticated account context is stable. It is the sole caller of `CustomSceneSubmissionController.restore()` and sole owner of recovery routing; pages render restored state/text but do not independently restore.
- [ ] Change `CustomSceneSubmissionController._registerApprovedMoment()` so it persists ready intent before publishing ready state. It must never discard the draft after registry success until a matching confirmation arrives.
- [ ] Change `AppCustomSceneCareTurnHandoffSink` to be navigation-only. Do not treat `GoRouter.push()` start or returned Future as confirmation.
- [ ] Add a confirmation channel from the Care Turn destination: resolve the matching generated registry bundle, validate it, establish the Care Turn snapshot/controller, make starter interactive, then emit `HandoffConfirmed(generatedContentId)`.
- [ ] Coordinator validates acknowledgement against current durable intent and then, idempotently, completes/deletes draft, clears continuation, and clears handoff intent. Ignore stale, duplicate, mismatched, or post-replacement confirmations.
- [ ] On route failure, timeout, destination parse failure, registry miss, initialization failure, app kill, or restart before acknowledgement, retain the same durable intent and content ID. Reopen only that Care Turn; never generate/register again.

### UI and downstream loop

- [ ] Update `custom_scene_input_screen.dart` and state model: `idle/editable` shows “帮我准备一句”; `submitting/reconciling` disables submit; `readyForHandoff`, failed, or timed-out handoff shows only “打开已准备内容”; in-flight handoff disables duplicate taps.
- [ ] Keep the original `generatedContentId` and `clientRequestId` immutable through every retry. No submit/generate/register path is available until matched confirmation or user chooses explicit abandonment.
- [ ] Add an independent “放弃这条内容” flow with second confirmation. Only this action clears a pending intent without a Care Turn acknowledgement, then returns to editing and permits a later new request identity.
- [ ] Keep Care Turn destination responsible only for resolution and acknowledgement. It must not delete draft/continuation storage. A failed destination must not confirm.
- [ ] Verify formal registry content flows through Care Turn to each canonical reaction, correct branch audio/TTS, Garden trace, and Today continuity; no consumer may use an invalid/unavailable bundle.

### Mobile acceptance tests

- [ ] Extend `custom_scene_submission_controller_test.dart`: persist-before-route ordering; app kill after registry success; restore same ID; confirmation-only cleanup; stale/duplicate acknowledgements; route failures/timeouts; no second request/generation/registration; explicit abandonment.
- [ ] Extend `custom_scene_input_screen_test.dart`: recovery Coordinator owns restoration; recovered draft text is rendered; ready/failed/timed-out CTA is “打开已准备内容”; multiple taps make one route attempt; original prepare CTA stays unavailable until confirmation/abandonment.
- [ ] Add destination tests for no confirmation on registry/init failure and one confirmation only after interactive starter state.
- [ ] Extend `generated_practice_content_registry_test.dart` and local-store tests for schema/version, role/reaction/provenance, starter-only/missing/duplicate support failures, atomic quarantine, account isolation, idempotent purge, non-sensitive diagnostics, and no automatic generation.
- [ ] Add integration coverage for response-loss, force-stop/restart, duplicate acknowledgement, invalid legacy ready intent, five branch audio selection, Garden/Today continuity, and accessibility focus recovery.
- [ ] Run targeted Flutter tests and final `cd mobile && flutter test` on the candidate.

## 3. Verifier and automated release gates

- [ ] Upgrade `tool/verify_m2_11_custom_scene_gates.dart` and its tests to enforce complete-bundle production invariants and source-path bans. Static checks must inspect production sources, not only method names, and allow explicit test/fake fixture directories only.
- [ ] Upgrade `tool/verify_m2_12_release_matrix.dart` and `test/tool/verify_m2_12_release_matrix_test.dart` from existence checks to parseable UAT-result checks.
- [ ] Define a checked-in, machine-readable UAT record template for every required case. Each record includes executor, timestamp/timezone, candidate SHA, APK identity, device/Android/TalkBack versions where relevant, prerequisites, ordered steps, expected/actual result, explicit status, evidence location, defects, and retest outcome.
- [ ] Verifier must reject missing fields, non-final/mismatched SHA/APK, duplicate/incomplete cases, `NOT RUN`, `BLOCKED`, `FAIL`, open defect references, and a human-accessibility claim inferred from hierarchy/semantics/ADB. It may validate records but never substitute for execution.
- [ ] Require all successful automated backend/mobile gates, complete-bundle tests, recovery/handoff/retry tests, legacy quarantine tests, and privacy-diagnostic tests before the matrix can report closure-ready.
- [ ] Ensure diagnostic/verifier fixtures contain only canonical non-sensitive scenes and opaque test data. Static verifier outputs must not echo utterance text or provider payloads.
- [ ] Update `scripts/verify-m2-12-release.ps1` only to orchestrate the strengthened gates; it must preserve `BLOCKED` as a closure failure.

## 4. Human UAT evidence

### Required execution cases

- [ ] Android generated-flow: enter approved non-sensitive canonical scene through Android, formal backend endpoint, formal Generator/Repair provider path, complete bundle registry, Care Turn, reaction, branch audio, Garden trace, and Today continuity.
- [ ] Event-written/response-lost reconciliation with same request identity and no duplicate generation/event.
- [ ] Force-stop during login/submission and process restart recovery, including same `readyForHandoff` intent and no second generation.
- [ ] All five reactions, each scene-matched support and its formal TTS audio branch.
- [ ] Actual TalkBack touch exploration, spoken order, labels, CTA/error/retry announcements, and return focus, performed and heard by a person.

### Authenticity, privacy, and audit requirements

- [ ] Use only approved non-sensitive canonical scenes, for example shoes, bath, water, teeth, and tidying. Never input child/family names, locations, contact data, medical/developmental details, routines, memories, or real household descriptions.
- [ ] Use real LLM provider output and, where the audio gate requires it, real TTS provider output. Fakes, fixtures, mocks, static JSON, seeded phrases, pre-recorded assets, test bytes, and loopback responses may support development but cannot PASS UAT.
- [ ] On unavailable credentials/network/quota/deployment, record `BLOCKED` with affected gate and sanitized reason. Do not convert supporting automated evidence into PASS.
- [ ] Record only candidate SHA/APK, canonical scene label, sanitized provider/model identity, irreversible trace/content/audio fingerprints, reaction, status, defect/retest references, and reviewed screenshots/recordings.
- [ ] Do not archive raw prompts, payloads, evidence chunks, utterance text, authorization material, account/device IDs, raw errors, or screenshots/recordings containing non-test private data.
- [ ] Before accepting screenshots or recordings, redact account/contact/notification/debug/token/URL/internal-ID information.

## Final closure checklist

- [ ] Backend complete-bundle, unified gate, full repair, Judge, activation, persistence, and static-fallback tests pass.
- [ ] Mobile durable recovery, destination confirmation, retry, explicit abandonment, legacy quarantine/purge, Care Turn, branch audio, Garden, and Today tests pass.
- [ ] Spring AI platform and generation-privacy verifiers pass; final Maven and Flutter suites pass on final candidate.
- [ ] Release-matrix verifier parses complete, passing, SHA-matched automated and human evidence with no open linked defect.
- [ ] Every required Android UAT and actual TalkBack record is `PASS` for the same final candidate SHA/APK.
- [ ] `docs/superpowers/verification/2026-07-28-m2-custom-scene-release-verification.md` is updated to RELEASE READY only after all previous boxes pass. It must retain `NOT RELEASE READY` otherwise.

Only after every box passes may #28 close and M2 become COMPLETE and RELEASE READY.
