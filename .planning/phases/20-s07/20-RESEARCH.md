# S07 Research — Mentor 审计 + 分发统计页面

## Summary

- This slice is **not greenfield anymore**. The roadmap-level S07 deliverable has already been split and implemented by later completed slices:
  - **S10** delivered the mentor audit incident workspace + live rate-limit context.
  - **S11** delivered the distribution stats workspace + bounded analytics contract.
  - **S04/S11** already mounted both pages into the shared admin shell and permission-based landing flow.
- Biggest surprise: there is **no existing plan or task file** under `.gsd/milestones/M006/slices/S07/`; the slice folder is effectively empty, while the real code/test seams already live elsewhere.
- Planner should treat S07 as a **composition / closure slice**, not as a fresh implementation, unless product still insists that “最近对话记录” means a true transcript/history browser instead of the current flagged-incident audit queue.
- The current system cannot truthfully fabricate transcript history from existing mentor truth sources. Per prior slice intelligence, `mentor_audit_logs` / `mentor_turns` do **not** provide a safe conversation-history bridge, and the default mentor runtime does not persist chat memory in a way admin can replay.

## Requirement focus

- Primary requirement supported here: **R052** — admin web delivery for mentor audit + distribution stats surfaces on top of the shared auth/RBAC shell.
- In practice, S10 advances the mentor-audit half of R052 and S11 advances the distribution-stats half; S07 now mainly needs roadmap-alignment and combined proof, not another feature build.

## Skills Discovered

- Already available and directly relevant:
  - `react-best-practices`
  - `spring-boot-engineer`
- Newly installed for this area:
  - `ant-design/antd-skill@ant-design`

## Recommendation

Per Karpathy Guidelines **“Simplicity First”** and **“Surgical Changes”**, do **not** re-implement mentor audit or distribution stats under a new S07 code path.

Recommended planner stance:

1. **Decide the semantic boundary first.**
   - If S07 means the current milestone-context behavior — flagged-first mentor audit, installation filter, incident evidence detail, live rate-limit context, plus bounded distribution stats — then S07 is already materially delivered by S10 + S11.
   - If S07 still requires a true “recent conversation history” browser, stop and replan: that is a **data-contract/schema problem**, not a page-polish problem.
2. **If current scope is acceptable, plan closure-only work.**
   - Aggregate verification across mentor + distribution + shell landing.
   - Record the composition explicitly in slice artifacts / roadmap state.
   - Avoid touching backend/frontend runtime code unless combined verification exposes a real gap.
3. **Only reopen implementation if a real gap is proven.**
   - The only likely gap is transcript/history semantics; everything else in the roadmap line item is already covered by shipped files and tests.

## Implementation Landscape

### 1) Empty S07 slice scaffold

- `.gsd/milestones/M006/slices/S07/` currently has **no plan/research/task files**.
- That means the planner is free to define S07 as a closure/integration slice without preserving earlier task IDs.

### 2) Mentor audit seam already shipped (S10)

**Backend**

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java`
  - Builds the admin read seam over `mentor_audit_logs` / `mentor_turns`.
  - Derives stable operator-facing `flagCode` values.
  - Groups incidents by `correlation_id`.
  - Loads audit timeline rows.
  - Loads delivered response evidence when a delivered turn exists.
  - Computes **live** rate-limit window counts per installation.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditService.java`
  - Validates `flag` and `limit`.
  - Shapes `QueueIncidentView` and `AuditDetailView`.
  - Makes missing delivery explicit through `deliveryState=delivered|missing_turn` instead of inventing transcript content.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditController.java`
  - Exposes:
    - `GET /api/admin/mentor/audits`
    - `GET /api/admin/mentor/audits/{correlationId}`
  - Protected by `@PreAuthorize("hasAuthority('mentor:audit')")`.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditProperties.java`
- `backend/admin-api/src/main/resources/application.yml`
  - Hold default/max queue limit plus rate-limit window/max-request config.

**Frontend**

- `admin-web/src/lib/mentorAuditClient.ts`
  - Typed parser for mentor queue/detail payloads.
- `admin-web/src/pages/MentorAuditPage.tsx`
  - URL-backed queue/detail context via `installationId`, `flag`, `selected`.
  - Explicit normalized-invalid-filter warning state.
  - Explicit empty / 404 / stale-session / 403-friendly surfaces.
  - Detail pane shows **incident evidence only** plus live rate-limit card.

**Proof already exists**

- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminMentorAuditWebTest.java`
- `admin-web/tests/mentor-audit.spec.ts`
- Prior slice summary: `.gsd/milestones/M006/slices/S10/S10-SUMMARY.md`

### 3) Distribution stats seam already shipped (S11)

**Backend**

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java`
  - Queries bounded analytics directly from `release_distribution_events` and `share_landing_events`.
  - Separates release overview/trend from raw share overview/trend/funnel.
  - Computes share→release handoff.
  - Emits normalized detail rows without leaking share token values.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsService.java`
  - Enforces fixed windows: `7d | 30d | 90d`.
  - Enforces fixed channel enum: `all | stable | beta`.
  - Caps detail rows via properties.
  - Keeps `channel` scoped only to release-side truth.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsController.java`
  - Exposes `GET /api/admin/distribution/stats`.
  - Protected by `@PreAuthorize("hasAuthority('distribution:read')")`.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsProperties.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - Wires the read repository into admin-api.

**Frontend**

- `admin-web/src/lib/distributionStatsClient.ts`
  - Typed parser for bounded stats payload.
- `admin-web/src/pages/DistributionStatsPage.tsx`
  - URL-backed `range` / `channel` state.
  - Invalid-query normalization warning while preserving raw URL context.
  - Explicit note that `channel` applies only to release-side data.
  - Uses lightweight antd + inline SVG/table rendering instead of introducing a chart library.

**Proof already exists**

- `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminDistributionStatsWebTest.java`
- `admin-web/tests/distribution-stats.spec.ts`
- Prior slice summary: `.gsd/milestones/M006/slices/S11/S11-SUMMARY.md`

### 4) Shared shell / permission seam already shipped (S04 + S11)

- `admin-web/src/app/routes.tsx`
  - Route catalog already includes `/mentor/audits` and `/distribution/stats`.
- `admin-web/src/app/access.ts`
  - Route access is derived from live permission codes; routes are effectively OR-scoped by their listed permissions.
- `admin-web/src/app/default-landing.ts`
  - Single-domain admins land directly on their only module.
  - Multi-domain admins and `super_admin` land via `Overview`.
- `admin-web/src/App.tsx`
  - Uses `/api/admin/me` as live browser truth.
  - Mounts both workspaces under the protected shell.
- `admin-web/src/layout/AdminLayout.tsx`
  - Renders the visible workspace switcher and current module diagnostics.
- `admin-web/tests/access-and-landing.spec.ts`
  - Already proves distribution-only landing and multi-domain overview behavior.
- `admin-web/tests/auth-and-rbac.spec.ts`
  - Already proves auth/session/403 guard semantics the S07 surfaces inherit.

### 5) Existing workbench primitives (reuse only if closure reveals a real UI gap)

- `admin-web/src/components/workbench/QueuePageShell.tsx`
- `admin-web/src/components/workbench/DetailContainer.tsx`
- `admin-web/src/components/workbench/ReasonRequiredConfirmation.tsx`

These primitives already underpin S05/S06 patterns. Do **not** force S07 rewrite to use them unless a specific closure gap requires it. Current mentor/distribution pages are already working.

## What to prove first

1. **Scope equivalence**
   - Confirm that the current S10/S11 behavior satisfies the roadmap wording for S07.
   - The only meaningful ambiguity is transcript/history vs incident-evidence semantics.
2. **Combined slice proof**
   - Run mentor backend contract + distribution backend contract + landing/browser specs together.
   - This proves the composed slice in the actual shell, not just two isolated child slices.
3. **Only then decide whether any code change is needed**
   - If combined proof passes and scope equivalence is accepted, S07 should become a documentation/roadmap closure slice.

## Natural seams for planning

### Task A — Closure decision / scope check

- Compare roadmap wording for S07 with shipped S10/S11 behavior.
- Output should be a one-line verdict: “S07 satisfied by composition” vs “S07 needs transcript-history replan”.

### Task B — Combined verification pack

- Reuse existing focused tests/specs instead of authoring new ones first.
- Include the shell landing spec because S07 is mounted through the route catalog and live permission resolver.

### Task C — Artifact / roadmap closure

- If Task A accepts current scope, write the missing S07 plan/summary artifacts as a composition slice and mark requirement advancement explicitly.
- If Task A rejects current scope, replan rather than patching the UI.

## Don’t Hand-Roll

- **Do not invent transcript history** from current mentor tables. That would violate the existing truth boundary.
- **Do not add a charting library** or React Query just to “improve” distribution stats; S11 intentionally kept this plain and bounded.
- **Do not duplicate route/auth logic** outside:
  - `admin-web/src/app/routes.tsx`
  - `admin-web/src/app/access.ts`
  - `admin-web/src/app/default-landing.ts`
  - `admin-web/src/App.tsx`
- **Do not create new analytics storage** for distribution stats. The existing read repository is already bounded and truthful.
- **Do not broaden changes beyond closure needs**. This is exactly where Karpathy’s “every changed line must trace directly to the goal” applies.

## Key constraints / gotchas

- Mentor audit is intentionally **incident-first**, not transcript-first.
- `flagCode` is the stable operator taxonomy; `failureCode` is lower-level evidence. Keep both roles distinct.
- Live rate-limit numbers are computed from recent `mentor_audit_logs` within the configured window, not from a separate cache.
- Distribution `channel` filtering does **not** apply to raw `share_landing_events`; it only scopes release-side analytics and release-side share-card handoff.
- Detail rows in distribution stats intentionally omit share tokens.
- The current protected shell treats `/api/admin/me` as live truth; local session storage is cache only.

## Verification

Use the existing proof seams before planning any new implementation.

### Core combined proof

- `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest`
- `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts`

### If shell/page code changes

- `npm --prefix admin-web run build`
- `npm --prefix admin-web run test:e2e -- auth-and-rbac.spec.ts access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts`

### If runtime truth-path assumptions are touched

- `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=MentorWebTest,MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest,DistributionPageWebTest,ShareLandingWebTest`

## Planner handoff

The lowest-risk plan is to treat S07 as a **closure slice backed by S10 + S11**, not as a new feature slice. Prove composition first. Re-open implementation only if the product meaning of “Mentor 审计” has changed back to full recent-conversation browsing, because that would require a new persisted conversation bridge and a fresh plan, not incremental UI work.
