# S06 Research — RAG 知识库管理页面

## Summary

- S06 is **targeted research**. The admin shell, auth seam, route guards, and workbench primitives already exist from S04/S05; the missing work is a truthful `Knowledge Ops` vertical slice on top of existing ingestion/KG data.
- This slice directly supports **R052** by replacing the current `Knowledge Ops` placeholder with real upload / queue / contradiction-review behavior while preserving the shared JWT + RBAC browser contract already proven in S04.
- Current codebase split is asymmetric: `admin-web` has no knowledge client or browser proof yet, and `admin-api` has no ingestion/KG beans at all. The only real ingestion/KG business logic still lives in `app-api`.

## Requirement targeting

- **R052 support:** S06 is the first slice that makes the S04 shell useful for knowledge operators rather than just navigable. It advances the requirement from “authz foundation exists” to “knowledge ops behavior is actually operable from the admin shell.”
- **Not enough to validate R052 alone:** the milestone’s “PENDING → PROCESSING → COMPLETED” browser proof still depends on a real upload execution seam and an offline-safe embedding strategy; the current compose defaults do not provide that automatically.

## Skills Discovered

- Installed `ant-design/antd-skill@ant-design`
- Installed `currents-dev/playwright-best-practices-skill@playwright-best-practices`

## What exists already

### Frontend

- `admin-web/src/pages/KnowledgeOpsPage.tsx`
  - Pure placeholder only. No real queue state, no client, no mutations, no URL-backed detail state.
- `admin-web/src/components/workbench/QueuePageShell.tsx`
  - Existing 2-column shell suitable for `queue + detail` split-view.
- `admin-web/src/components/workbench/DetailContainer.tsx`
  - Simple card wrapper already used by `Users`.
- `admin-web/src/components/workbench/ReasonRequiredConfirmation.tsx`
  - Intended primitive, but currently still **user-disable-specific** in wording, placeholder text, and test ids.
- `admin-web/src/app/routes.tsx`
  - Current `knowledge-ops` route is a single top-level page with read-side permissions only: `rag:read` / `kg:read`.
  - `ADMIN_ROUTE_PERMISSION_CODES` does **not** include `rag:write` or `kg:review` even though backend RBAC already defines them.
- `admin-web/src/app/access.ts`
  - Route access is OR-based: a user can access the `knowledge-ops` route if they match **any** required permission.
  - Important implication: a user with only `kg:read` can enter the page, so the page itself must hide/disable ingestion surfaces.
- `admin-web/src/auth/http-client.ts`
  - Shared protected axios client already handles `FormData` correctly: it intentionally does **not** auto-set JSON `Content-Type` when the body is `FormData`.
  - This means multipart upload can reuse the same auth/session transport.

### Backend

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionController.java`
  - Real consumer-side upload/status/retry endpoints already exist:
    - `POST /api/v1/ingestion/upload`
    - `GET /api/v1/ingestion/jobs/{id}`
    - `POST /api/v1/ingestion/jobs/{id}/retry`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java`
  - Real orchestration path exists: MinIO upload → async processing → Tika parse → split → metadata enrich → `PgVectorStore.add(...)`.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java`
  - Storage contract for `ingestion_jobs` already exists and includes `findAll()`, `findByStatus()`, `updateStatusPending()`, `updateCompleted()`, `updateFailed()`.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgController.java`
  - Real contradiction/notification behavior already exists on app-api:
    - `GET /api/v1/kg/notifications`
    - `PUT /api/v1/kg/notifications/{id}/read`
    - `GET /api/v1/kg/contradictions`
    - `PUT /api/v1/kg/contradictions/{id}/resolve`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradictionRepository.java`
  - Direct JDBC access to `kg_contradictions`.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgAdminNotificationRepository.java`
  - Direct JDBC access to `kg_admin_notifications`.
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java`
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java`
  - These establish the current **admin read-model pattern**: shared JDBC repositories live in `common`, and `admin-api` wires them via explicit config.
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - This is the right wiring seam for new knowledge repositories.
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
  - Backend RBAC already knows:
    - `rag:read`
    - `rag:write`
    - `kg:read`
    - `kg:review`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java`
  - Shared `@RestControllerAdvice` already standardizes admin error payloads as `{timestamp,status,code,message,details}`.

### Schema / migrations

- `backend/db-migration/src/main/resources/db/migration/V11__create_ingestion_tables.sql`
  - `ingestion_jobs` exists already.
- `backend/db-migration/src/main/resources/db/migration/V14__create_knowledge_graph_tables.sql`
  - `kg_contradictions` and `kg_admin_notifications` exist already.
- There is **no dedicated admin command audit table** for ingestion retry / KG resolve today.

### Existing proof harness

- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionControllerTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionServiceIntegrationTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/kg/KgControllerTest.java`
  - These are the best regression harnesses if ingestion/KG code gets extracted or rewired.
- `admin-web/tests/users-management.spec.ts`
- `admin-web/tests/mentor-audit.spec.ts`
  - These are the browser pattern references for S06: URL-backed state, explicit inline error handling, real compose stack, and typed API helpers.

## Don’t hand-roll

- Do **not** create a second auth transport or bypass the shared session/refresh seam; use `requestJson` / protected axios.
- Do **not** let the browser call `app-api` directly for ingestion/KG. Keep the browser contract on `/api/admin/**`.
- Do **not** invent a second client parsing style. Follow `usersClient.ts` / `mentorAuditClient.ts` conventions.
- Do **not** build a speculative global knowledge store. Existing admin pages use URL query as truth + page-local fetch state.
- Do **not** hide permission drift in button-level `if`s only. Extend the shared permission truth where route/access metadata is defined.

## Recommendation

1. Build a real **admin knowledge BFF** on `/api/admin/**`; keep the browser contract admin-only.
2. Reuse the current `common -> admin-api` read-model pattern for queue/detail queries.
3. Treat **KG** and **ingestion** differently on the write path:
   - KG resolve / notification read can be implemented directly in `admin-api` against shared tables.
   - Ingestion upload / retry cannot be “just SQL”; actual processing still lives in `IngestionService` and depends on MinIO + embeddings + vector store.
4. Follow Karpathy’s rules explicitly here:
   - **Simplicity first:** add the smallest truthful page/API surface that proves the flow.
   - **Surgical changes:** do not refactor unrelated shell/nav code.
   - **Goal-driven execution:** define proof as concrete checks (row appears, status changes, retry updates in place, resolve advances queue, notification read state changes).

## Viable backend approaches

### A. Extract a shared ingestion seam (recommended)

- Extract the smallest reusable ingestion execution/storage boundary that both `app-api` and `admin-api` can call.
- Likely extraction candidates:
  - `IngestionJob`
  - `IngestionRepository`
  - a thin orchestration service for upload / retry / process
- Why this is best:
  - avoids service-to-service auth hacks
  - avoids duplicating ingestion logic
  - keeps the browser contract canonical at `/api/admin/**`
- Cost:
  - higher blast radius because `admin-api` currently has none of the MinIO / VectorStore / embedding wiring.

### B. Wire selected ingestion beans into admin-api (faster, messier)

- Keep app-api source as-is, but import/wire the needed ingestion service/config into `admin-api`.
- Why it works:
  - fastest path to an admin endpoint that can upload/retry without changing browser contracts.
- Why it’s risky:
  - `AdminApiApplication` currently scans only `com.zhangspaghetti.babytalk.admin`
  - importing app-api ingestion beans drags in MinIO/Spring AI config and creates a brittle parallel runtime.

### C. Proxy admin-api -> app-api over HTTP (not recommended right now)

- Lowest code, but currently blocked by auth shape.
- Current `app-api` security requires the **consumer** bearer flow for ingestion/KG endpoints; there is no service-to-service trust path for admin-api.
- Do not pick this unless you first design explicit internal auth.

**Planner guidance:**

- Pick **A** if you can afford one backend extraction task.
- Avoid **C** unless internal auth is added first.
- For KG, direct admin-side JDBC/service work is straightforward even if ingestion takes path A.

## Implementation landscape

### Frontend seams

- `admin-web/src/pages/KnowledgeOpsPage.tsx`
  - Replace placeholder with the real workbench.
  - Natural internal split:
    1. URL-backed page state
    2. ingestion queue list + upload affordance
    3. KG contradiction list + detail pane
    4. mutation feedback / confirm flows
  - Because route access is coarse OR-based, the page itself must gate sub-surfaces:
    - ingestion read/write: `rag:read` / `rag:write`
    - KG read/review: `kg:read` / `kg:review`
- `admin-web/src/lib/knowledgeOpsClient.ts` (new)
  - Mirror `usersClient.ts` / `mentorAuditClient.ts`:
    - typed response parsers
    - query builders
    - list/detail/mutation methods
    - `requestJson` over shared protected transport
- `admin-web/src/components/workbench/ReasonRequiredConfirmation.tsx`
  - Currently not generic enough for retry / resolve.
  - Either generalize surgically (copy + label + test ids as props) or create a dedicated knowledge-action confirmation component.
- `admin-web/src/app/routes.tsx`
  - Extend `ADMIN_ROUTE_PERMISSION_CODES` with `rag:write` and `kg:review` before adding write affordances.
  - Keep the top-level `knowledge-ops` route unless you have a clear reason to split routing; a URL query like `?view=ingestion|kg-review` is simpler than refactoring the shell into nested menus.
- `admin-web/src/auth/http-client.ts`
  - Multipart upload can reuse this seam directly.

### Backend seams

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java`
  - Register new knowledge read/write repositories here.
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/...`
  - Best fit for new JDBC read models over:
    - `ingestion_jobs`
    - `kg_contradictions`
    - `kg_admin_notifications`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthController.java`
  - Reuse shared exception handling via `AdminApiContractException`; do not hand-shape new error bodies.
- Existing app-api domain sources worth reusing / extracting from:
  - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionController.java`
  - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionService.java`
  - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java`
  - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgController.java`
  - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradictionRepository.java`
  - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgAdminNotificationRepository.java`

## Key constraints / surprises

1. **Default compose upload cannot truthfully reach `COMPLETED` today without a real embedding key or a dev stub.**
   - `IngestionService` always writes through `PgVectorStore`.
   - `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/EmbeddingConfiguration.java` always builds a real `OpenAiEmbeddingModel`.
   - `docker-compose.yml` defaults `BABY_TALK_EMBEDDING_API_KEY` to `dev-placeholder-key`.
   - So S06 can probably prove `PENDING -> PROCESSING -> FAILED`, but not the required `... -> COMPLETED`, unless execution either:
     - supplies a real embedding key via env, or
     - introduces a deterministic dev embedding path.
2. **No SSE / realtime transport exists yet.**
   - Search found no admin SSE/WebFlux adapter in current code.
   - For S06, bounded polling on visible/selected rows plus explicit `updating/stale` UI is the minimal truthful path.
   - Do not block this slice on the later S12 transport work.
3. **Route access is coarser than the page needs.**
   - Today a user with only `kg:read` can still access the shared `knowledge-ops` page.
   - The page must not render ingestion upload/retry controls unless the user actually has `rag:*` access.
4. **No shared knowledge command-audit skeleton exists yet.**
   - `Users` disable piggybacks on `consent_audit_logs`.
   - Knowledge ops has no equivalent transactionally coupled audit surface.
   - Planner should budget this explicitly or consciously defer full audit formalization; do not invent two unrelated ad hoc formats.
5. **The “reusable” confirmation primitive is still users-specific.**
   - Downstream slices will trip over this if they assume it is generic.

## Natural task decomposition

1. **Backend read model + contracts first**
   - Add admin knowledge repositories and admin-api read endpoints for:
     - ingestion queue list/detail
     - KG contradiction list/detail
     - notification list
   - Verify those contracts before touching the page.
   - This unblocks frontend typing and URL-state work immediately.
2. **Frontend workbench shell second**
   - Replace `KnowledgeOpsPage` with URL-backed state, queue rendering, and KG split-view.
   - Add the typed client and all loading / empty / error / partial states.
3. **Mutation path third**
   - Implement upload / retry / resolve / mark-read APIs.
   - Then wire buttons, confirm flows, and post-action refresh/focus behavior.
4. **Browser proof last**
   - Add `admin-web/tests/knowledge-ops.spec.ts`.
   - Reuse the style from `users-management.spec.ts` / `mentor-audit.spec.ts`:
     - wait for concrete network calls
     - assert URL query persistence
     - assert inline failure states instead of page resets
   - Make the upload completion strategy explicit before writing the spec:
     - real embedding key, or
     - deterministic dev stub, or
     - fixture-driven browser state progression plus separate backend upload contract proof.

## Verification plan

### Backend

- New focused admin-api tests (names up to executor, but split by concern):
  - ingestion queue/detail contracts
  - KG queue/detail + notification contracts
  - retry invalid-state / idempotency behavior
  - resolve invalid-state / idempotency behavior
  - RBAC matrix for `rag:read`, `rag:write`, `kg:read`, `kg:review`
- Regression tests to rerun if ingestion/KG code is extracted/shared:
  - `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=IngestionControllerTest,IngestionServiceIntegrationTest,KgControllerTest`
  - `./backend/mvnw -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminRbacWebTest`

### Frontend

- `npm --prefix admin-web run build`
- New browser proof:
  - `npm --prefix admin-web run test:e2e -- knowledge-ops.spec.ts`

### Browser proof should explicitly cover

- login -> `/knowledge-ops`
- upload file -> queue row appears
- status surface changes without full-page reset
- failed job -> retry in place
- KG queue left pane -> detail right pane
- resolve keeps queue context and focuses the next row or shows all-clear
- notification read state updates in place
- role-scoped admin sees only the sub-surface they own

## Specific planner watchouts

- Add a tiny deterministic **PDF** fixture for browser upload. Current repo only has `backend/app-api/src/test/resources/test-document.txt`.
- Keep the browser on relative `/api/admin` paths; do not introduce cross-origin app-api browser calls.
- If you extend `ADMIN_ROUTE_PERMISSION_CODES`, also extend backend fixture creation so Playwright role seeding can grant the new write permissions.
- If you choose polling for S06, scope it to visible/selected rows and surface `stale` / `updating` explicitly so S12 can replace transport later without rewriting the page model.

## Sources

- Local code only; no external docs were needed for this slice.
