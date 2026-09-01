# Task 6 report — Spring AI 2 integration hardening

## Delivered

- Added `MentorProviderRetryContractTest`: real Spring AI 2 `OpenAiChatModel` against local JDK `HttpServer`; a 500 response then a valid completion proves `maxRetries=1` makes exactly two outbound requests.
- Added Mentor and KG options coverage for total-attempt semantics: `10 -> 9` retries and `1 -> 0` retries.
- Added Flyway `V26__upgrade_chat_memory_for_spring_ai_2.sql`.
  It adds Spring AI 2's required `sequence_id`, backfills existing conversations deterministically by timestamp and `ctid`, enforces `NOT NULL`, and creates a conversation/sequence index.
- Updated direct chat-memory test fixtures and migration smoke coverage for the Spring AI 2 schema.
- Updated migration expected version/count to `26` / `25`.

## Verification

`TESTCONTAINERS_RYUK_DISABLED=true` was required only for local test execution: Docker Desktop could not reach Docker Hub to pull `testcontainers/ryuk:0.14.0`. Tests still ran against local `pgvector/pgvector:pg16` Testcontainers. No test contacted an AI endpoint.

- Spring AI focused suite: 139 passed.
- Patch platform regression gate: 167 passed.
- `DbMigrationSmokeTest`: 6 passed, including legacy-row backfill, `NOT NULL`, and idempotent V26 reapplication.
- `mvn -pl app-api -DskipTests compile`: passed.
- Dependency tree: Spring AI `2.0.0`, Spring Boot `4.0.7`, Spring Framework `7.0.8`; no Spring Framework 6 artifacts.
- Source boundary: no `new OpenAiApi`; no Baby Talk imports of Jackson 2 core/databind.

## Notes

The focused JDBC tests first exposed the actual Spring AI 2 compatibility issue: `PostgresChatMemoryRepositoryDialect` now selects and inserts `sequence_id`. V26 preserves existing deployed rows rather than relying on a clean-schema-only fix, and the migration smoke test verifies its legacy-row backfill and idempotent reapplication.

## Follow-up hardening

- V26 now creates a database-owned `spring_ai_chat_memory_sequence_id_seq` default and a unique `(conversation_id, sequence_id)` index. Legacy V13 rows are backfilled before the `NOT NULL`, unique index, and default; timestamp ties use `ctid` only for this one migration because V13 had no immutable historical message key.
- Migration smoke coverage creates an isolated schema through Flyway target V13, inserts legacy rows, then migrates that same schema through Flyway target V26. It proves preserved timestamp-tied ordering, non-null/default/unique schema, and a new insert that omits `sequence_id`; it does not simulate V13 by dropping current objects or manually executing V26 SQL.
- Chat-memory fixtures now omit `sequence_id`; the integration test verifies database-generated same-timestamp ordering through the Spring AI repository and the exact 10-message sliding window.
- The retry contract now configures `MentorProperties.aiMaxAttempts=2` via `MentorProviderConfiguration.openAiOptions`; the real Spring AI model makes exactly two local HTTP requests after one 500 response.
- The custom-scene plan records the only current execution evidence as disposable Testcontainers. V25/V26 are immutable; any non-disposable execution requires follow-up generated-content migrations at V27+.

## Follow-up verification

- `MentorProviderRetryContractTest`: 1 passed.
- `ChatMemoryIntegrationTest,ConversationSessionServiceTest`: 15 passed.
- `DbMigrationSmokeTest`: 6 passed.
- Task 6 focused suite: 140 passed.
- Platform regression gate: 167 passed.

## P1-T6 auth flake fix (2026-09-01)

### Root cause and fix

- Each UI login first navigates to `/overview`, but `requestOverviewStreamResponse` sent only the SSE `Accept` header and credentials. The admin API therefore returned 401, causing `refreshStreamSession` to race the protected Axios refresh path against the same rotating refresh token.
- The stream request now reads `loadStoredSession()?.accessToken` on every attempt and sends `Authorization: Bearer <accessToken>` when present. The existing refresh retry recursively reads the persisted replacement access token; no shared mutex or broad auth refactor was added.
- The focused regression test was observed RED before the production change (missing `Authorization`); after the change it verifies both the first valid-session request and the refreshed retry request.

### Verification

- `pnpm exec vitest run unit/lib/overview-client.test.ts`: 5 passed.
- `pnpm test`: 10 files / 39 tests passed.
- `pnpm typecheck`: passed.
- `pnpm lint`: passed.
- `pnpm format`: passed.
- `pnpm build`: passed; existing Vite circular-chunk and large-chunk warnings remain.
- QA `docker-desktop` / `babytalk-qa`: app-api, admin-api, gateway, and admin-web deployments were `1/1`, running, and had zero restarts. Temporary service forwards exposed app-api on 8080 and admin-api on 8081; both actuator health probes returned `UP`.
- Single E2E run from the 89d worktree: `preset-scenes.spec.ts --retries=0` ran all 10 cases and passed in 56.8s. No retry, flaky result, failure, or failure trace.
- Cleanup completed: Vite and both temporary forwards stopped; ports 3100, 8080, and 8081 were confirmed free. QA data and deployments were not changed.
