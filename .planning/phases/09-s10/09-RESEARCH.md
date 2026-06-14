# S10 — Research

**Date:** 2026-04-24

## Summary

The mentor runtime is already a strong truth source for **flagged incidents**. `MentorService` writes stable audit phases to `mentor_audit_logs` and delivered success/fallback rows to `mentor_turns`, and the existing app-api tests already prove blocked fallback, provider timeout/malformed/unavailable, rate limiting, and transaction boundaries. From a planner’s perspective, the backend truth for “which mentor requests deserve operator attention” already exists.

What does **not** exist yet is the admin seam. `admin-api` has no mentor controller/service/read model, `AdminPermissionCatalog` defines `mentor:audit` but no controller consumes it, and `admin-web` is still the S01 login/protected-stub proof. The frontend session model also drops backend `permissions`, so even after a mentor page exists the browser cannot truthfully guard it on `mentor:audit` until `authClient` expands.

Highest-risk discovery: current persistence can truthfully power a **correlation-level incident queue**, but not a true **conversation/session transcript**. `mentor_turns` / `mentor_audit_logs` do not persist `conversationId`; `spring_ai_chat_memory` stores transcript by `conversation_id` only; and default local/test `DevMentorProvider` never writes chat memory at all. Likewise, rate-limit history stores only `rate_limited=true/false`, not remaining budget at incident time. So the planner must make one explicit decision up front:

- **Incident-first S10**: queue + detail built from redacted request summary, delivered response text, audit timeline, provider failure state, and current live rate-limit status.
- **Transcript-first S10**: add a persistence bridge first (conversation join key, and probably dev-mode chat-memory writing) before promising a real session transcript.

Do not silently build the first and label it as the second.

## Recommendation

Applying **karpathy-guidelines** explicitly:

- **Think before coding:** make one explicit product/data decision before tasking — is S10 an **incident queue** or a **true session transcript** slice? The current schema only proves the first.
- **Simplicity first:** keep S10 read-only. The roadmap asks to open flagged conversations, inspect context, and return to queue; it does **not** require ack/resolve/mutation commands yet.
- **Surgical changes:** keep admin reads in `backend/common` + `admin-api`; do not make `admin-api` depend on `app-api` runtime classes.
- **Goal-driven:** lock four proofs now — (1) flagged queue rows, (2) detail surface with provider/rate-limit context, (3) queue-context restore/deep link, (4) `mentor:audit` permission guard.

Preferred plan shape:

1. **Backend-first, read-only admin contract**
   - Add a mentor audit read repository in `backend/common`.
   - Add read-only `admin-api` service/controller under `com.zhangspaghetti.babytalk.admin.mentor`.
   - Key detail requests by `correlation_id`, because that is the stable key current truth surfaces already share.

2. **Truthful initial detail surface**
   - Queue risk from `mentor_audit_logs.event_type` / `phase` / `failure_code` / `rate_limited`.
   - Timeline from `mentor_audit_logs`.
   - Delivered fallback/success text from `mentor_turns.response_text`.
   - Request evidence from redacted `request_summary`.
   - Rate-limit card split into:
     - **incident outcome** (`rate_limited` or not, plus failure code), and
     - **current live status** (current count + configured `limit/window`) computed at read time.
   - Do **not** pretend to show historical remaining budget unless you add persistence for it.

3. **If full transcript is non-negotiable, add the bridge before UI**
   - Persist `conversation_id` alongside mentor audit/turn rows.
   - Reuse `spring_ai_chat_memory` as the raw transcript store instead of inventing a second transcript table.
   - Ensure dev/local proof mode also writes chat memory (or equivalent transcript truth), otherwise local/CI admin transcript tests will stay hollow.

4. **Frontend guard must use permissions, not guessed roles**
   - Backend `/api/admin/me` already returns `permissions`.
   - `admin-web/src/lib/authClient.ts` currently drops them.
   - S10 UI must stop losing `mentor:audit` before any route/nav gating is considered complete.

## Skills Discovered

Existing relevant skills already present:

- `spring-boot-engineer`
- `spring-ai`
- `react-best-practices`
- `karpathy-guidelines`

Installed during research for downstream units:

- `ant-design` (`ant-design/antd-skill@ant-design`)
- `playwright-best-practices` (`currents-dev/playwright-best-practices-skill@playwright-best-practices`)

## Implementation Landscape

### Existing backend truth surfaces

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`
  - Real `/api/v1/mentor/chat` entrypoint. Best seed surface for creating blocked/timeout/rate-limit incidents truthfully in tests/E2E.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
  - Writes stable audit phases and turn rows.
  - `buildRequestSummary()` already gives redacted prompt evidence.
  - Provider failures already normalize to stable codes.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorRepository.java`
  - Current JDBC truth for `mentor_turns` / `mentor_audit_logs`.
  - Has the right low-level queries for correlation lookups and current-window counts.
  - But it is **package-private inside app-api**, so `admin-api` cannot reuse it directly.
- `backend/db-migration/src/main/resources/db/migration/V4__create_mentor_tables.sql`
  - Current mentor tables and indexes.
  - Good for `correlation_id` and `installation_id` reads.
  - Missing today: `conversation_id`, rate-limit snapshot fields, any explicit admin flag column.
- `backend/db-migration/src/main/resources/db/migration/V13__create_chat_memory_table.sql`
  - Existing transcript store by `conversation_id` only.
  - No `installation_id` / `correlation_id` bridge.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ConversationSessionService.java`
  - Current conversation-id lifecycle logic.
  - Useful only if planner chooses a full transcript path, because today its result never lands in mentor audit/turn tables.
- `backend/app-api/src/main/resources/sql/s06_success_queries.sql`
  - Already contains mentor failure breakdown and installation timeline queries.
  - Best language source for queue badge taxonomy and runbook proof semantics.
- `docs/runbooks/s05-mentor-runtime-contract.md`
  - Canonical failure-code / redaction language.
  - Some details are stale vs current runtime (pre-module paths, older allowed surfaces/modes), so treat it as semantics source, not literal file-path truth.

### Existing admin seams to extend

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
  - Already defines `mentor:audit`; S10 should be the first controller to consume it.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - Existing place to wire new `common` JDBC repositories explicitly.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java`
  - `/api/admin/me` already returns `permissions`; browser model just does not preserve them yet.
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminRbacWebTest.java`
  - Existing `SpringBootTest + MockMvc + Postgres` pattern to copy for mentor queue permission and contract tests.

### Existing frontend/testing seams to extend

- `admin-web/src/App.tsx`
  - Still only login + protected stub. No mentor route, no queue shell, no detail surface.
- `admin-web/src/lib/authClient.ts`
  - Current session model stores `roles` only and drops backend `permissions`; must expand before `mentor:audit` UI gating is real.
- `admin-web/src/main.tsx`
  - Current theme is still the S01 purple proof, not the locked admin workbench theme. Avoid deepening this foundation.
- `admin-web/playwright.config.ts`
- `admin-web/playwright.global-setup.ts`
- `admin-web/tests/admin-login.spec.ts`
  - Existing working Playwright harness. S10 should add a mentor audit spec to this harness instead of inventing a second browser test path.
- `tool/inspect_mentor_facts.dart`
- `tool/verify_s06.dart`
  - Existing root-safe proof-pack pattern. Best template for a future `tool/verify_m006_s10_mentor_audit.dart`.

### Missing seams S10 likely needs

If planner keeps the slice **incident-first / read-only**:

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditService.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditController.java`
- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminMentorAuditWebTest.java`
- `admin-web/src/pages/MentorSafetyPage.tsx` (or equivalent route after shell work lands)
- `admin-web/tests/mentor-audit.spec.ts`
- `docs/runbooks/m006-s10-mentor-audit.md`
- `tool/verify_m006_s10_mentor_audit.dart`

If planner chooses **full transcript / session detail**, also expect:

- a new Flyway migration after V17
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorRepository.java`
- probably chat-memory wiring so dev mode produces transcript truth too

## Natural Seams / Task Order

1. **Resolve the data-truth decision first**
   - Decide whether S10 ships a truthful incident detail now or a true session transcript.
   - Do not let the UI imply session semantics if the backend only proves correlation-level incidents.

2. **Build the admin read model in the right module**
   - Put read-only mentor/admin repositories in `backend/common` as plain JDBC classes.
   - Wire them in `AdminDataAccessConfiguration`.
   - Keep `admin-api` services/controllers under `com.zhangspaghetti.babytalk.admin.*`.

3. **Add admin contract tests before UI**
   - Copy the `AdminRbacWebTest` style and seed mentor truth through direct DB inserts or real `/api/v1/mentor/chat` seed calls.
   - Prove `401 / 403 / 200` for `mentor:audit` plus stable queue/detail JSON shape.

4. **Only then add queue/detail UI**
   - Reuse the existing admin browser/runtime harness.
   - Preserve queue context via URL search params + selected `correlationId`; that is sufficient for this slice and avoids inventing a custom global store.
   - Keep detail in the same surface; deep links can reopen the same selected incident by query param.

5. **Finish with proof-pack + runbook alignment**
   - Extend the existing inspect/verify pattern.
   - Update runbook language to match the actual admin queue taxonomy so ops does not need a translation layer.

## Verification

### Fresh research-time evidence

- `npm --prefix admin-web run build` ✅ pass
  - current bundle is already `647.51 kB`; S10 should prefer route-level page separation and avoid piling more UI into the login stub.
- `dart run tool/inspect_mentor_facts.dart --help` ✅ pass
  - confirms the existing root-safe mentor inspect surface is available to extend.
- `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=MentorWebTest,MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest,ChatMemoryIntegrationTest,ConversationSessionServiceTest` ✅ pass
  - surefire reports show green proof for:
    - `MentorWebTest` (9 tests)
    - `MentorRateLimitConcurrencyTest` (2 tests)
    - `MentorTransactionBoundaryTest` (4 tests)
    - `ChatMemoryIntegrationTest` (5 tests)
    - `ConversationSessionServiceTest` nested suites (all green)

### Useful S10 verification ladder

1. **Backend mentor truth stays green**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl app-api -am test -Dtest=MentorWebTest,MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest`
2. **New admin mentor contract**
   - `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest`
3. **Frontend build smoke**
   - `npm --prefix admin-web run build`
4. **Browser queue/detail smoke**
   - `npm --prefix admin-web run test:e2e -- mentor-audit.spec.ts`
5. **Root-safe proof pack**
   - `dart run tool/verify_m006_s10_mentor_audit.dart`

### Truthful seed strategy for tests/E2E

Prefer creating incidents through the real mentor runtime instead of hand-authoring opaque DB rows:

- normal request → success row
- blocked keyword → `blocked_fallback`
- prompt with `[timeout]` → `provider_timeout`
- repeated requests beyond window → `mentor_rate_limited`

This reuses the current dev provider seams and keeps admin queue evidence aligned with real runtime semantics.

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---|---|---|
| admin read JDBC wiring | `backend/common` plain classes + `AdminDataAccessConfiguration` | matches S03 pattern and avoids cross-module runtime coupling |
| mentor failure taxonomy | `MentorService` + `s05-mentor-runtime-contract.md` + `s06_success_queries.sql` | keeps queue labels aligned with already-tested semantics |
| browser harness | existing Playwright config/global setup/login spec | avoids a second E2E harness |
| root-safe proof pack | `tool/verify_s06.dart` / `tool/inspect_mentor_facts.dart` | gives S10 a reproducible verifier instead of manual SQL-only instructions |

## Constraints

- `admin-api` does **not** depend on `app-api`; `MentorRepository` is package-private and cannot be imported across modules.
- `AdminApiApplication` scans `com.zhangspaghetti.babytalk.admin.*`; any new shared repository outside that tree still needs explicit wiring.
- current frontend auth model discards `permissions`, so `mentor:audit` gating is not real until session types are widened.
- current admin-web is still the login proof, not a finished workbench shell.
- existing mentor audit/turn tables are intentionally redacted; do not backslide into dumping raw prompt/provider bodies there.
- existing runbook/task artifacts have drift:
  - `.gsd/milestones/M006/S10-TASKS.md` still references pre-modular `backend/src/...` paths
  - `docs/runbooks/s05-mentor-runtime-contract.md` still describes older allowed surfaces/modes than current `application.yml`

## Risks or Gotchas

- **Transcript bridge gap:** current mentor truth supports incident detail, not true session transcript. `conversationId` never lands in mentor tables, and dev mode does not populate chat memory.
- **Correlation vs session mismatch:** `correlation_id` is a single request key, not a conversation/thread key. If the UI labels this as a “session” without new persistence, it will mislead operators.
- **Historical rate-limit snapshot gap:** `mentor_audit_logs` stores `rate_limited` as a boolean, but not remaining budget at incident time. Only current/live rate-limit status is reconstructible without schema changes.
- **Conversation ID length mismatch:** `ConversationSessionService` accepts/truncates IDs to 128 chars, but `SPRING_AI_CHAT_MEMORY.conversation_id` is `varchar(36)`. Any transcript-oriented work should not deepen this inconsistency.
- **Frontend guard drift:** backend `/api/admin/me` already returns permissions, but `admin-web/src/lib/authClient.ts` drops them. S10 UI can look wired while still not proving real RBAC if this is ignored.
- **Design drift risk:** current admin-web theme is still the purple S01 proof. If S10 page work lands before the shell/theme cleanup, later slices will have to restyle it.
