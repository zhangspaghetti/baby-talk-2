# M2 #28 Closure: Complete Generated Bundles and Durable Care Turn Handoff

## Problem Statement

Caregivers need generated care language that remains safe, scene-specific, and recoverable through a complete Care Turn. The current M2 path can create a starter while using fixed support text, validate only part of generated content, lose a registered result before Care Turn is established, and claim release evidence without proving real Android/provider/TalkBack execution. These gaps can expose a caregiver to irrelevant support, duplicate generation, lost prepared content, or an unsupported release claim.

Issue #28 must remain open until M2 can prove a Complete Generated Bundle, durable confirmed handoff, valid downstream Care Turn behavior, and auditable release evidence on one final mobile/backend/provider candidate.

## Solution

M2 will treat generated care content as a Complete Generated Bundle: one starter plus five scene- and reaction-matched supports. Generator and Repair will return the whole typed bundle in one provider response per attempt. Every utterance will pass deterministic validation, follow the approved terminal/repairable policy, and require complete-bundle Judge effective PASS plus activation provenance before registration and ACTIVE.

The mobile app will persist a ready-for-handoff intent after registry registration, recover it through one app-level coordinator, and remove it only after Care Turn reports that matching content has become interactively available. Users may explicitly abandon a pending handoff after a second confirmation, but that is cancellation, never successful handoff. Retrying always opens the same registered content and never generates again.

M2 release evidence will be machine-validated but human-executed: real backend deployment, real LLM and TTS providers, approved non-sensitive canonical scenes, Android recovery scenarios, all audio branches, and actual TalkBack. All evidence must identify the same mobile candidate, deployed backend, and sanitized provider/configuration identity.

## User Stories

1. As a caregiver, I want one generated starter and one appropriate support for every baby reaction, so that I can continue a care moment without requesting another generation.
2. As a caregiver, I want support after “配合” to continue the actual care action, so that encouragement fits the moment.
3. As a caregiver, I want support after “犹豫” to lower pressure or offer a choice, so that I can respond gently.
4. As a caregiver, I want support after “不想” to name the feeling and reduce force, so that I do not receive coercive language.
5. As a caregiver, I want support after “没反应” to simplify language or add a sensory cue, so that I have a usable next step.
6. As a caregiver, I want support after “其他” to acknowledge safely and openly, so that unfamiliar reactions do not receive a generic or unsafe fallback.
7. As a caregiver, I want every phrase to match my scene, so that bathing, putting on shoes, and other care actions do not receive interchangeable templates.
8. As a caregiver, I want unsafe generated text rejected as a whole bundle, so that one unsafe branch cannot become available later.
9. As a caregiver, I want repairable quality issues corrected across the whole bundle, so that the final Care Turn remains internally consistent.
10. As a caregiver, I want a completed generated bundle to remain available if the app closes while opening Care Turn, so that I do not lose prepared content.
11. As a caregiver, I want app restart to restore my pending prepared content automatically, so that I do not have to remember a draft or submit again.
12. As a caregiver, I want “打开已准备内容” to reopen the same Care Turn after navigation fails or times out, so that retry never creates duplicate content.
13. As a caregiver, I want the app to show “帮我准备一句” only when no prepared content remains, so that I do not accidentally submit a second request.
14. As a caregiver, I want an explicit two-step abandonment choice, so that accidental navigation failure does not silently discard prepared content.
15. As a caregiver, I want Care Turn to open only after the prepared bundle is valid and interactively ready, so that a route transition is not mistaken for usable content.
16. As a caregiver, I want each reaction to play audio for its displayed support, so that spoken guidance matches what I see.
17. As a caregiver, I want generated Care Turn actions to continue into Garden and Today, so that the care moment is not isolated from the rest of the app.
18. As a caregiver, I want invalid old generated content to be unavailable rather than guessed or template-filled, so that I never consume unverifiable content.
19. As a caregiver, I want a clear re-preparation path for invalid old content, so that I can choose to start a fresh request without hidden regeneration.
20. As a caregiver switching accounts, I want pending content and cleanup isolated by account, so that another account never consumes or purges my data.
21. As a privacy-conscious caregiver, I want UAT and diagnostics to avoid my family’s text and identifiers, so that release verification does not become a private-data archive.
22. As an accessibility user, I want a person to verify actual TalkBack reading order, touch exploration, error/retry announcements, and return focus, so that semantic widgets alone do not stand in for usable accessibility.
23. As a release manager, I want every M2 UAT result tied to one mobile APK, backend deployment, provider profile, and configuration fingerprint, so that I can prove the tested system was the release candidate.
24. As a release manager, I want `FAIL`, `BLOCKED`, and `NOT RUN` to prevent closure, so that incomplete external-provider or device work cannot appear complete.
25. As a QA reviewer, I want UAT to use approved non-sensitive canonical scenes through real providers, so that testing is both authentic and privacy-safe.
26. As a QA reviewer, I want branch-level scene/reaction/speakability/audio assessments without storing phrase bodies, so that quality can be audited without retaining user content.
27. As a backend engineer, I want typed complete-bundle provider contracts, so that missing, duplicate, or unknown reaction branches fail before persistence.
28. As a safety owner, I want terminal and repairable violations explicitly classified, so that Repair and Judge cannot change deterministic safety policy.
29. As a mobile engineer, I want one Recovery Coordinator to own restore and routing, so that page lifecycle rebuilds cannot duplicate recovery or navigation.
30. As a Care Turn engineer, I want confirmation to occur only after the starter is interactively established, so that cleanup never precedes destination readiness.
31. As a verifier maintainer, I want release tooling to parse actual UAT results and artifact identities, so that a present evidence file cannot masquerade as a passing test.
32. As a maintainer, I want fixed supports and starter-derived bundles blocked from production source, so that later refactors cannot reintroduce the old fallback.
33. As a maintainer, I want legacy records quarantined before safe purge, so that incompatible local data cannot race with active consumers.
34. As a product owner, I want any M2 scope reduction recorded as explicit supersession, so that M3 cannot silently inherit unclosed release risk.

## Implementation Decisions

- A Complete Generated Bundle is one starter plus supports for exactly `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`.
- Bundle-level fields describe the shared scene. Each utterance independently owns content, pronunciation, TPR action, delivery guidance, difficulty, display order, role, reaction, and provider provenance.
- Starter is `role=starter` with no reaction. Every support is `role=reaction_support` with one canonical reaction. Provenance identifies generation or repair origin and never encodes role or reaction.
- Each generation attempt and each repair attempt consumes exactly one typed provider response containing all six utterances. Bounded repair attempts remain allowed.
- Missing, duplicate, unknown, free-text, or otherwise invalid reaction keys fail typed parsing. Production never derives supports from a starter, appends fixed supports, replaces a failed support with generic text, or exposes a starter-only response.
- Deterministic validation runs independently for every utterance before registration. Terminal codes are `OUTPUT_PII`, `OUTPUT_BIDI_CONTROL`, `OUTPUT_ADULT_VIOLENT`, `OUTPUT_DANGEROUS_MEDICAL`, `UNTRUSTED_METADATA`, `DATABASE_OVERFLOW`, and `INVALID_ENUM`.
- Repairable codes are `MISSING_TPR_ACTION`, `MISSING_DELIVERY_GUIDANCE`, `FIELD_ROLE_MISMATCH`, `META_INSTRUCTION`, `COURSE_OR_SCORING_FRAMING`, and `MARKDOWN_OR_TEMPLATE`.
- A terminal violation rejects the full bundle without Repair, Judge, persistence, registration, or ACTIVE. A repairable violation triggers complete-bundle Repair, final six-utterance validation, complete-bundle Judge, and application-computed effective PASS before activation provenance can be written.
- Registration persists a durable ready-for-handoff intent with its generated content identity before navigation. Authentication-only continuation state can clear after registration; handoff state cannot.
- One app-level Recovery Coordinator owns durable-work discovery, restoration, and routing after authentication becomes stable. Input screens render recovered state and text but do not independently restore.
- Router navigation only initiates delivery. Care Turn confirms only after it resolves the matching valid registry bundle, establishes controller/snapshot state, and exposes an interactive starter.
- A matching `HandoffConfirmed` is the only successful-completion signal. Before it, user abandonment with a second confirmation is a distinct cancellation path. Duplicate, stale, or mismatched confirmations are harmless.
- Ready, handoff-failed, and handoff-timed-out states with a durable intent and valid content identity expose only “打开已准备内容”. It reuses the same content and request identities, does not register again, and does not call generation.
- Generation, authentication, and registration failures without a valid ready intent retain their own error/retry behavior and cannot present an open-prepared-content action.
- Incompatible legacy bundles are atomically marked `invalid/unavailable`, blocked from every consumer, diagnosed with non-sensitive metadata only, and later purged idempotently within account scope. They are never inferred, repaired, rejudged, or automatically regenerated.
- Current M2 Android UAT requires real LLM output and real TTS output for starter plus all five reaction branches. Only explicit scope supersession can alter this requirement.
- UAT uses approved non-sensitive canonical scenes and archives only sanitized artifact/provider/configuration identities, irreversible fingerprints, reviewed media, structured quality judgements, and defect/retest status.

## Testing Decisions

### Primary seams

The highest behavioral seam is the existing custom-scene generation-to-Care-Turn path: submit a scene, receive/register a Complete Generated Bundle, recover durable intent, establish Care Turn, confirm handoff, select a reaction, and observe matching audio plus downstream continuity. This is the primary mobile integration and Android UAT seam.

Backend uses the existing generation orchestration seam: typed provider adapter through deterministic gate, Repair, Judge, and activation. Mobile persistence uses the existing generated registry and draft-continuation seam. These seams avoid inventing test-only transport or a second recovery owner.

### Automated behavior

- Test Generator and Repair adapters through their typed provider boundary: one provider call per attempt, six required branches, strict parse failure for malformed structures, and preserved provenance.
- Test orchestration by observable outcome: terminal violation rejects before Repair/Judge/persistence; repairable violation repairs the complete bundle, validates all six again, and activates only after effective PASS.
- Parameterize every terminal and repairable code across every utterance position. Assert public lifecycle outcomes rather than private method calls except provider-call count, which is a contract requirement.
- Test canonical scenes with explicit expected branch semantics, not merely non-empty or different strings.
- Test source verification against production sources with explicit fake/test fixture allowlists.
- Test controller/coordinator behavior at the durable draft and route-command boundary: persist-before-route, recovery after loss, confirmation-only cleanup, stale/duplicate confirmation safety, retry without new request, and explicit abandonment.
- Test Care Turn destination behavior at its public readiness boundary: no confirmation on registry or initialization failure, exactly one matching confirmation only after interactive starter state.
- Test registry consumers at their read boundary: schema/role/reaction/provenance validation, atomic legacy quarantine, account isolation, idempotent purge, safe diagnostics, and no implicit generation.
- Test user-visible states: only valid pending handoffs show “打开已准备内容”; ordinary failed submissions retain their own retry paths.
- Test release-matrix parsing with complete/invalid UAT record fixtures. Assert missing or mismatched mobile/backend/provider identities, non-PASS status, unresolved defects, and inferred TalkBack claims block closure.

### Human verification

- Execute Android generated flow, response-loss reconciliation, force-stop/restart recovery, all five reaction audio branches plus starter, and actual TalkBack on the same final candidate.
- Use formal backend and real providers. Fixture, mock, static, loopback, test-byte, or pre-recorded evidence cannot pass human UAT.
- Record executor, date/timezone, mobile SHA/APK, backend SHA/artifact, sanitized environment identity, provider mode/profile, configuration fingerprint, device/Android/TalkBack versions, prerequisites, steps, expected/actual result, status, evidence, defects, and retest.
- Record structured, body-free branch review fields: scene match, reaction match, low-pressure language, direct speakability, displayed-branch audio match, and reviewer result.

## Out of Scope

- Declaring M2 complete or release-ready before every automated and human gate passes.
- Treating provider credentials, network, quota, or deployment unavailability as PASS; these remain `BLOCKED`.
- Replacing real LLM/TTS Android UAT with fixtures, static assets, mocks, controlled loopback, UI hierarchy, widget tests, or inferred accessibility.
- Persisting raw family scenes, utterance bodies, prompts, provider payloads, tokens, identifiers, or unredacted evidence in UAT records or diagnostics.
- Starter-only compatibility, fixed-support migration, provenance inference, partial-bundle activation, or automatic regeneration of incompatible legacy content.
- A second page-owned recovery or routing path.
- Moving any listed closure condition to M3 without explicit scope supersession.

## Further Notes

- #28 is the sole closure vehicle for this scope and must remain open until every listed requirement passes.
- `BLOCKED`, `FAIL`, and `NOT RUN` are closure failures. The release matrix may report them; it cannot reinterpret them.
- The verified deployment is the tuple of mobile candidate SHA/APK, backend SHA/artifact, sanitized environment identity, active provider mode/profile, and configuration fingerprint.
- Existing domain definitions and ADRs govern terminology: Complete Generated Bundle, Bundle Activation, Generated Output Violation Policy, Custom-scene Recovery Coordinator, Handoff Confirmation, Ready-for-Handoff UI, Authentic Generated-flow UAT, Invalid Legacy Bundle, and Legacy Bundle Quarantine.
