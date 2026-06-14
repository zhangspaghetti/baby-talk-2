# S05 — Research

**Date:** 2026-04-26

## Summary

The codebase has **22 runtime JdbcTemplate-using files** spread across three modules. `common` owns 8 repository classes (all under `admin/` sub-packages plus `ingestion/`); `app-api` owns 12 files spanning auth, KG, palace, mentor, distribution, share, and caregiver invite; `admin-api` owns 2 (a nested `AdminAuthRepository` inside `AdminAuthService.java` and the `AdminDataAccessConfiguration` wiring class). Two additional app-api files (`ChatMemoryConfiguration`, `EmbeddingConfiguration`) pass a `JdbcTemplate` instance to Spring AI framework beans (`JdbcChatMemoryRepository`, `PgVectorStore`) — these are Spring AI infrastructure pass-throughs, not user-land SQL execution, and will be noted as explicit carve-outs rather than migrated.

**MyBatisPlus, Druid, and Hutool are absent from all four pom.xml files.** The parent pom uses `spring-boot-starter-parent 3.4.4`; `app-api` and `admin-api` each declare `spring-boot-starter-jdbc` (which pulls HikariCP); `common` declares only `spring-jdbc`. All three need new dependencies: `common` gets `mybatis-plus-core` for annotation types and `BaseMapper`; `app-api` and `admin-api` get `mybatis-plus-spring-boot3-starter` and `druid-spring-boot-3-starter`. Hutool is added to the parent `dependencyManagement` and consumed in modules that need its utility methods.

The latest Flyway migration is **V17** (`create_admin_rbac_permissions`). S05 starts at V18+ only if schema changes are required by MyBatisPlus entities (e.g., column alias reconciliation); preliminary analysis indicates no schema changes are needed since entity fields map 1:1 to existing columns. Key migration risks: (1) `PROPAGATION_REQUIRES_NEW` + in-JVM lock in `MentorRepository.insertAuditAndCountWindow` must be preserved exactly; (2) `SELECT FOR UPDATE` in auth repositories requires raw SQL via `@Select` annotation or XML; (3) `AdminDataAccessConfiguration` currently wires all repositories as `@Bean` methods — MyBatisPlus mapper interfaces require `@MapperScan` on the app class instead, changing the wiring topology; (4) complex multi-CTE queries in `AdminDistributionStatsReadRepository` and `AdminMentorAuditReadRepository` cannot use `BaseMapper` convenience methods and will use `@Select` with inline SQL.

## Recommendation

**4-batch migration plan** (ordered by risk, each batch gets parity tests before advancing):

### Batch 1 — Admin Read-Model (common module, read-mostly)

Safest first because these repositories are primarily read-only, contain no pessimistic-lock patterns, and changing them doesn't affect app-api availability.

- `common/.../admin/distribution/AdminDistributionStatsReadRepository.java`
- `common/.../admin/knowledge/AdminKnowledgeIngestionRepository.java`
- `common/.../admin/knowledge/AdminKnowledgeKgRepository.java`
- `common/.../admin/mentor/AdminMentorAuditReadRepository.java`
- `common/.../admin/users/AdminUserReadRepository.java`

### Batch 2 — Admin Auth/Session + RBAC (security-critical; admin-api + common)

These have transactional writes, token rotation, `SELECT FOR UPDATE` patterns and are security-sensitive.

- `admin-api/.../auth/AdminAuthService.java` (nested `AdminAuthRepository`)
- `common/.../admin/rbac/AdminRbacRepository.java`
- `admin-api/.../config/AdminDataAccessConfiguration.java` — remove `@Bean` JdbcTemplate wiring; replace with `@MapperScan`

### Batch 3 — Common Ingestion (simpler CRUD, shared by both runtimes)

Single repository, simple CRUD, shared by both admin-api and app-api via `IngestionService`.

- `common/.../ingestion/IngestionRepository.java`

### Batch 4 — App-API Consumer/Auth/Share/Mentor/KG (largest batch; app-api module only)

All app-api runtime repositories. `AuthConsentSyncRepository` is the highest complexity here (full auth lifecycle + interaction events).

- `app-api/.../service/AuthConsentSyncRepository.java`
- `app-api/.../service/CaregiverInviteRepository.java`
- `app-api/.../service/ConversationSessionService.java` (queries `spring_ai_chat_memory` directly)
- `app-api/.../service/DistributionRepository.java`
- `app-api/.../service/MentorRepository.java`
- `app-api/.../service/ShareLandingRepository.java`
- `app-api/.../kg/KgEntityRepository.java`
- `app-api/.../kg/KgRelationshipRepository.java`
- `app-api/.../kg/KgContradictionRepository.java`
- `app-api/.../kg/KgAdminNotificationRepository.java`
- `app-api/.../palace/PalaceKeywordRepository.java`

**Spring AI infrastructure carve-outs (keep JdbcTemplate, document as intentional):**

- `common/.../config/EmbeddingConfiguration.java` — passes JdbcTemplate to `PgVectorStore.Builder`; Spring AI API boundary
- `app-api/.../config/ChatMemoryConfiguration.java` — passes JdbcTemplate to `JdbcChatMemoryRepository.builder()`; Spring AI API boundary

## Implementation Landscape

### Key Files

**Batch 1 — admin read-model (common module)**

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/distribution/AdminDistributionStatsReadRepository.java` — Batch 1: multi-CTE cross-join analytics on `release_distribution_events` + `share_landing_events`; uses dynamic SQL builder + `applyStatementTimeout()` (`set local statement_timeout`)
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeIngestionRepository.java` — Batch 1: `ingestion_jobs` read-model; simple list/find with optional status filter; `statement_timeout` guard
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/knowledge/AdminKnowledgeKgRepository.java` — Batch 1: `kg_contradictions` + `kg_entities` read-model; left-join queries; `statement_timeout` guard
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/mentor/AdminMentorAuditReadRepository.java` — Batch 1: complex multi-CTE audit queue with `case/when` flag classification; dynamic optional filters; `statement_timeout` guard
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/users/AdminUserReadRepository.java` — Batch 1: `accounts` + `account_sessions` + `consent_audit_logs`; mixed read/write (delete, tombstone, status update); pagination; dynamic filter builder
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/overview/AdminOverviewReadRepository.java` — Batch 1 (indirect): delegates to other repositories; no direct JdbcTemplate; no migration needed but wiring changes when deps migrate

**Batch 2 — admin auth/session + RBAC (common + admin-api)**

- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/auth/AdminAuthService.java` — Batch 2: nested `AdminAuthRepository` class; `admin_principals`, `admin_roles`, `admin_principal_roles`, `admin_refresh_tokens`; `SELECT FOR UPDATE` for token rotation; transactional insert/update/expire patterns
- `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminRbacRepository.java` — Batch 2: RBAC write + read; `admin_principal_roles`, `admin_role_permissions`, `admin_permissions`; in-loop insert for bulk permission grants; `AuthoritySnapshot` aggregation with ResultSet callbacks
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/config/AdminDataAccessConfiguration.java` — Batch 2: wires all common repositories as `@Bean(JdbcTemplate)`; must be replaced with `@MapperScan` strategy

**Batch 3 — common ingestion**

- `backend/common/src/main/java/com/zhangspaghetti/babytalk/ingestion/IngestionRepository.java` — Batch 3: `ingestion_jobs` CRUD; simple insert/update/select patterns; UUID primary key; used by both admin-api and app-api via `IngestionService`

**Batch 4 — app-api consumer/auth/share/mentor/KG**

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncRepository.java` — Batch 4: largest repository; `sms_challenges`, `accounts`, `account_sessions`, `account_refresh_tokens`, `consent_audit_logs`, `interaction_events`; `SELECT FOR UPDATE` via `lockRefreshToken`; `ON CONFLICT DO NOTHING` for idempotent event insert
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/CaregiverInviteRepository.java` — Batch 4: `households`, `household_members`, `caregiver_invites`, `household_shared_context`, `interaction_events`; manual upsert (UPDATE then INSERT if 0 rows); complex cross-join household projection CTE
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ConversationSessionService.java` — Batch 4: queries `spring_ai_chat_memory` directly for session timeout logic; may need to stay JdbcTemplate if Spring AI doesn't expose last-message-time API
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/DistributionRepository.java` — Batch 4: `release_distribution_events` insert + list; simple CRUD
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorRepository.java` — Batch 4: `mentor_audit_logs`, `mentor_turns`; **critical**: `insertAuditAndCountWindow` uses `PROPAGATION_REQUIRES_NEW` + ConcurrentHashMap per-installationId lock; this pattern must be preserved exactly with `@Transactional(propagation = Propagation.REQUIRES_NEW)`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/ShareLandingRepository.java` — Batch 4: `share_landing_cards`, `share_landing_events`; simple insert/find
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgEntityRepository.java` — Batch 4: `kg_entities` CRUD; UUID PK
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgRelationshipRepository.java` — Batch 4: `kg_relationships` CRUD; UUID PK; `BigDecimal confidence` column
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradictionRepository.java` — Batch 4: `kg_contradictions` CRUD; UUID PK
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgAdminNotificationRepository.java` — Batch 4: `kg_admin_notifications` CRUD; UUID PK
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceKeywordRepository.java` — Batch 4: `vector_store` + `content_tsv` full-text search via `plainto_tsquery`; JSONB metadata filter; not a standard CRUD — must remain raw SQL `@Select`

**Infrastructure files (pom changes)**

- `backend/pom.xml` — add `mybatis-plus-spring-boot3-starter`, `druid-spring-boot-3-starter`, `hutool-all` to `dependencyManagement`
- `backend/common/pom.xml` — add `mybatis-plus-core` (annotations + BaseMapper, no autoconfiguration); remove `spring-jdbc` dependency (superseded by MyBatisPlus core which brings it transitively)
- `backend/app-api/pom.xml` — replace `spring-boot-starter-jdbc` with `mybatis-plus-spring-boot3-starter` + `druid-spring-boot-3-starter` + `hutool-all`
- `backend/admin-api/pom.xml` — same as app-api

### Build Order

**Batch 1 parity gate:** After migrating admin read-model repositories, run `AdminDistributionStatsWebTest`, `AdminKnowledgeOpsWebTest`, `AdminMentorAuditWebTest`, `AdminOverviewWebTest`, `AdminUsersWebTest`. All must pass with same HTTP responses. Druid slow query log must appear in logs.

**Batch 2 parity gate:** After migrating AdminAuthRepository + AdminRbacRepository + rewiring `AdminDataAccessConfiguration` to `@MapperScan`, run `AdminAuthWebTest` and `AdminRbacWebTest`. Token rotation and `SELECT FOR UPDATE` behavior must be verified via concurrent auth test.

**Batch 3 parity gate:** After migrating `IngestionRepository`, run `AdminKnowledgeOpsWebTest` (which exercises ingestion via admin-api) plus `IngestionServiceIntegrationTest` (app-api). Both must pass.

**Batch 4 parity gate:** After migrating all app-api repositories, run the full `app-api` test suite: `JwtTokenLifecycleWebTest`, `AuthConsentSyncWebTest`, `CaregiverInviteApiWebTest`, `MentorWebTest`, `ShareLandingWebTest`, `ShareLinkApiWebTest`, `DistributionPageWebTest`, `MentorRateLimitConcurrencyTest`, `MentorTransactionBoundaryTest`. The concurrency test is the critical parity checkpoint for `MentorRepository`.

### Verification Approach

**Runtime JdbcTemplate audit (zero-usage check):**

```bash

# Should find zero results after migration (excludes Spring AI infra files)

rg 'JdbcTemplate' backend/common/src/main/java --include='*.java' \
  --glob '!*EmbeddingConfiguration*' -l
rg 'JdbcTemplate' backend/app-api/src/main/java --include='*.java' \
  --glob '!*ChatMemoryConfiguration*' -l
rg 'JdbcTemplate' backend/admin-api/src/main/java --include='*.java' -l
```

**All 4 batch parity tests:**

```bash
cd backend
mvn -pl admin-api test -Dtest="AdminDistributionStatsWebTest,AdminKnowledgeOpsWebTest,AdminMentorAuditWebTest,AdminOverviewWebTest,AdminUsersWebTest,AdminAuthWebTest,AdminRbacWebTest" -am
mvn -pl app-api test -Dtest="JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,CaregiverInviteApiWebTest,MentorWebTest,MentorRateLimitConcurrencyTest,MentorTransactionBoundaryTest,ShareLandingWebTest,DistributionPageWebTest" -am
```

**Druid slow-query metrics visible:**

- Access `http://localhost:8080/druid/index.html` (or `/druid/sql.html`) — requires Druid wall + stat filters enabled in `application.yml`
- Or verify via Actuator: `GET /actuator/druid` (if `management.endpoints.web.exposure.include=druid` configured)

## Don't Hand-Roll

| Problem | Existing Solution | Why Use It |
|---------|------------------|------------|
| ORM mapping + CRUD boilerplate | MyBatisPlus `BaseMapper<T>` | Provides `insert`, `selectById`, `updateById`, `deleteById`, `selectPage` without writing SQL; plugs into Spring transaction management |
| Dynamic SQL (non-trivial WHERE) | MyBatisPlus `QueryWrapper` / `LambdaQueryWrapper` | Type-safe fluent condition builder; avoids manual `StringBuilder` SQL construction as seen in `AdminDistributionStatsReadRepository` |
| Complex multi-CTE raw SQL | MyBatisPlus `@Select("...")` + `@SelectProvider` | When QueryWrapper is insufficient (CTEs, window functions, `set local statement_timeout`), drop to annotated SQL — MyBatisPlus delegates to standard MyBatis, full SQL expressiveness available |
| Connection pool + slow query metrics | Druid `druid-spring-boot-3-starter` | Replaces HikariCP; adds built-in SQL monitoring panel, slow query log, connection pool health; compatible with Spring Boot 3 via `DruidDataSourceAutoConfigure` |
| Utility functions (string, date, UUID) | Hutool `hutool-all` | Replaces ad-hoc `truncate()`, `Timestamp.from()` + null checks; `StrUtil`, `DateUtil`, `IdUtil` cover common patterns in existing repositories |
| Upsert pattern (UPDATE then INSERT) | MyBatisPlus `IService.saveOrUpdate()` or PostgreSQL `ON CONFLICT ... DO UPDATE` in `@Select` | `CaregiverInviteRepository.upsertSharedContext` currently uses two separate updates; MyBatisPlus `saveOrUpdate` handles this or keep raw SQL with `ON CONFLICT DO UPDATE SET ...` for clarity |

## Constraints

- **Spring Boot 3.4.4** — must use `mybatis-plus-spring-boot3-starter` 3.5.9+ (Spring Boot 3 compatible); older `mybatis-plus-boot-starter` artifact targets Spring Boot 2 and will fail at class loading
- **No auto-increment PKs** — all tables use application-assigned string or UUID PKs; every MyBatisPlus entity must declare `@TableId(type = IdType.INPUT)` or `@TableId(type = IdType.ASSIGN_UUID)` — default `AUTO` will break inserts
- **Flyway is the schema owner** — `db-migration` module controls all DDL; MyBatisPlus `ddlAuto` must NOT be enabled; no `@TableName` entity can add `create table` side effects
- **`@MapperScan` scope** — both `AppApiApplication` and `AdminApiApplication` need `@MapperScan("com.zhangspaghetti.babytalk")` covering both the app package and common package (`com.zhangspaghetti.babytalk.admin.*`, `com.zhangspaghetti.babytalk.ingestion`, etc.); single broad scan is cleaner than listing sub-packages
- **Tests may retain JdbcTemplate** per D115 — `AbstractIntegrationTest` and web test helpers that directly query the DB for assertions do not need migration; audit only covers `src/main/java`
- **Existing `@Transactional` boundaries** — Spring's `@Transactional` annotation works identically with MyBatisPlus; no changes to service-layer transaction annotations needed; only `TransactionTemplate(REQUIRES_NEW)` in `MentorRepository` needs explicit attention
- **PostgreSQL dialect** — MyBatisPlus global config must declare `dbType: POSTGRE_SQL` in `MybatisPlusConfig` to get correct `LIMIT/OFFSET` pagination SQL; default MySQL dialect generates wrong syntax

## Common Pitfalls

- **`AdminDataAccessConfiguration` still wires JdbcTemplate beans** — if the config class is not refactored alongside the repository migrations, Spring context will fail to start because the old `@Bean` methods reference repository classes that no longer accept JdbcTemplate constructors. Fix: refactor `AdminDataAccessConfiguration` in Batch 2 to remove all JdbcTemplate `@Bean` methods; mappers auto-register via `@MapperScan`.
- **`set local statement_timeout`** — `AdminDistributionStatsReadRepository`, `AdminKnowledgeIngestionRepository`, `AdminKnowledgeKgRepository`, and `AdminMentorAuditReadRepository` all call `jdbcTemplate.execute("set local statement_timeout = '2000ms'")` before heavy queries. With MyBatisPlus, this needs a `@Before`/interceptor or a dedicated `@Update("set local statement_timeout = '2000ms'")` method call in the mapper. If omitted, slow admin queries will run without the safeguard.
- **MyBatisPlus entity field name mapping** — Java record fields use camelCase; PostgreSQL columns use snake_case. Default MyBatisPlus config enables `map-underscore-to-camel-case: true`, so `account_id` → `accountId` works automatically. However, columns named with reserved words or unusual names (e.g., `is_read` → `isRead`) need `@TableField("is_read")` explicit annotation.
- **`MentorRepository` in-JVM lock** — `ConcurrentHashMap<String, Object> rateLimitLocks` is an instance field. MyBatisPlus doesn't change this; the `@Repository` bean stays singleton. However if the mapper interface replaces the class, the `requiresNewTx` TransactionTemplate and the lock map must both be preserved in a wrapper service/decorator, not embedded in the mapper.
- **KgAdminNotificationRepository / ConversationSessionService** — `ConversationSessionService` queries `spring_ai_chat_memory` directly by timestamp. If Spring AI updates the table schema, this breaks. Consider replacing with Spring AI's `ChatMemory` API to retrieve messages and derive the timestamp client-side; this eliminates the JdbcTemplate usage entirely from this file.
- **PalaceKeywordRepository** — uses `plainto_tsquery` + JSONB `@>` operators and `ts_rank` sorting. Cannot use `QueryWrapper` at all. Must use `@Select` with full SQL preserved verbatim.

## Open Risks

- **`MyBatisPlus + PgVectorStore coexistence`** — `PgVectorStore` (Spring AI) uses its own JdbcTemplate for `vector_store` table operations. MyBatisPlus `@MapperScan` must NOT scan the Spring AI packages, and vice versa. Risk: if both MyBatisPlus and PgVectorStore compete for the same DataSource bean after Druid replaces HikariCP, connection pool initialization order matters. Mitigation: verify both beans start cleanly in Batch 1 before touching app-api.
- **Druid DataSource proxy + Spring AI JDBC** — Spring AI's `JdbcChatMemoryRepository` and `JdbcChatMemoryRepository` use Spring's `JdbcTemplate` which wraps the `DataSource`. When Druid replaces HikariCP, all JDBC calls route through Druid's proxy. This is expected and desired (all SQL monitored), but test it in Batch 1 since admin-api doesn't use Spring AI — it's the safest first DataSource swap.
- **`SELECT FOR UPDATE` with MyBatisPlus** — MyBatisPlus doesn't natively support pessimistic locking annotations. `findRefreshTokenForUpdate` (AdminAuthRepository) and `lockRefreshToken` (AuthConsentSyncRepository) must use raw SQL via `@Select("SELECT ... FOR UPDATE")`. If the mapper method doesn't specify `@Select` and uses `selectById`, the `FOR UPDATE` clause is omitted silently, leading to a race condition. Must be covered by `MentorTransactionBoundaryTest` and `VerifyChallengeConcurrencyTest`.
- **Schema change requirement (V18+)** — current analysis shows no schema changes are needed. Risk: MyBatisPlus entity mapping may reveal column naming mismatches (e.g., `household_id` used as both PK and FK across tables with no surrogate `id` column). Confirm at Batch 1 entity creation time; if any mismatch requires a schema patch, add V18 as an additive index-only or alias column migration.
- **Hutool version compatibility** — `hutool-all 5.8.x` is a Java 8+ artifact; Spring Boot 3.4.4 runs Java 17. The `hutool-all` jar is compatible with Java 17 but the `javax.*` usages inside some hutool modules (crypto, HTTP) may conflict with `jakarta.*` in Spring Boot 3. If conflicts appear, switch to `hutool-core` only.
