# Stage R1 Security And Privacy Issues

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Security Audit  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed, blocking R2 decisions required

## Summary

No real hardcoded JWT, API key, private key, or obvious production secret was found in the mobile source during the read-only audit. However, the app has security and privacy decisions that must be resolved before core-flow refactoring starts.

Security/privacy score: 4 / 10.

## Blocking Findings

### SEC-001: Mentor chat can send free-form user text before confirmed login/consent policy

Evidence:

- `mobile/lib/features/mentor/presentation/mentor_notifier.dart` sends prompt, installation ID, and context summary through `MentorApiService.sendChat`.
- Chat availability checks loading/offline state, but the audit did not find a hard gate for signed-in parent consent.

Risk: A child or parent could send personally sensitive child/family context to backend/AI services before a clear consent gate. This is a red-line risk for a child-focused product.

Required R2 decision: confirm whether mentor chat must require parent login and accepted consent before any network call. Recommended: yes.

### SEC-002: Access token parameters are not consistently injected into Authorization headers

Evidence:

- Account, household, mentor, and dynamic practice API service paths accept or operate near access token state, but the audit found request helper paths that do not consistently set `Authorization: Bearer ...`.
- `mobile/lib/core/network/auth_interceptor.dart` exists but does not establish a complete token injection strategy.

Risk: Protected APIs may silently rely on cookies, fail with 401, or maintain two competing auth sources.

Required R2 decision: choose canonical mobile auth source. Recommended: Bearer JWT with one authenticated client/interceptor and tests for every protected API.

### SEC-003: Child and household data are stored locally without an approved data classification policy

Evidence:

- Onboarding includes child display name and birth/age information.
- Household shared context includes baby, continuity, and garden summaries.
- Practice and mentor local stores use Isar/local files without an R2-approved encryption/deletion policy.

Risk: Children and household context can remain on device storage, backups, or shared devices after consent withdrawal or account deletion.

Required R2 decision: classify local data and decide encryption, backup exclusion, and deletion/consent withdrawal behavior.

### SEC-004: Installation ID policy is not approved for consent-sensitive flows

Evidence:

- Stable installation ID is generated and stored under app support.
- The audit identified non-CSPRNG generation and consent-boundary ambiguity.

Risk: A stable installation ID can be a persistent identifier under child privacy regimes.

Required R2 decision: decide whether installation ID can be generated or sent before consent. Recommended: local-only before consent, never sent before consent, resettable/deletable.

## Medium Findings

### SEC-005: Sensitive models may expose values through generated `toString()`

Evidence: Freezed-generated models can include access tokens, refresh tokens, invite tokens, or URLs in default string output.

Risk: Crash logs, debug logs, or test failure output can leak sensitive values.

R2 action: define redacted debug display helpers and ban logging whole sensitive models.

### SEC-006: External URL handling needs HTTPS-only and domain allowlist policy

Evidence: Audit found URL handling paths that allow `http` and lack explicit official-domain allowlists.

Risk: Upgrade/share/invite flows can be downgraded or redirected to untrusted destinations.

R2 action: define allowlists for official upgrade, invite, and share domains; test `http`, `javascript:`, unknown domain, and malformed URLs.

### SEC-007: Integration fake token model can hide access/refresh bugs

Evidence: In-memory demo backend reuses simple session-like values as access and refresh token substitutes.

Risk: Tests can miss token rotation, replay, and expiry failures.

R2 action: use distinct fake access and refresh tokens and add rotation/replay tests.

## R2 Security Plan Requirements

1. Auth canonicalization plan: Bearer JWT versus Cookie, one authenticated client, protected endpoint tests.
2. Consent gate plan: mentor chat, dynamic practice, share/create-link, and any AI outbound path.
3. Local data classification: account, onboarding, household, practice events, mentor facts, installation ID.
4. Sensitive logging/redaction: model redaction and logging rules.
5. External URL allowlist: HTTPS-only and known domains.

## Required Human Decisions

See:

- `ai/context/pending-decisions/need-confirmation-r1-mentor-consent-gate.md`
- `ai/context/pending-decisions/need-confirmation-r1-auth-strategy.md`
- `ai/context/pending-decisions/need-confirmation-r1-local-sensitive-data.md`