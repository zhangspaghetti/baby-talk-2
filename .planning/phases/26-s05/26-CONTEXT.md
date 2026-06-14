# Phase 26 Context

Migrated from GSD-2 slice S05: S05

# S05 Context — Repo-wide Runtime Persistence Migration

**Status:** Not yet started (planning research completed)
**Depends on:** S01 ✅, S02 ✅

---

## Goal

Migrate all "our own" JdbcTemplate usage in `common`, `app-api`, `admin-api` to MyBatisPlus adapter style. Add Druid connection pool for slow-query metrics. Add Hutool utility library. Runtime audit confirms no direct JdbcTemplate in our own repository code.

---

## Files To Migrate (20 files — our own code)

**EXCLUDED from migration (Spring AI framework — cannot change):**

- `backend/common/src/main/java/.../config/EmbeddingConfiguration.java` — PgVectorStore needs JdbcTemplate
- `backend/app-api/src/main/java/.../config/ChatMemoryConfiguration.java` — JdbcChatMemoryRepository needs JdbcTemplate

**Batch 1 — admin read-model (all in `backend/common/src/main/java`):**

1. `admin/rbac/AdminRbacRepository.java` (459 lines)
2. `admin/users/AdminUserReadRepository.java` (311 lines)
3. `admin/mentor/AdminMentorAuditReadRepository.java` (350 lines)
4. `admin/distribution/AdminDistributionStatsReadRepository.java` (438 lines)
5. `admin/knowledge/AdminKnowledgeIngestionRepository.java` (147 lines)
6. `admin/knowledge/AdminKnowledgeKgRepository.java` (304 lines)

**Batch 2 — admin auth (`backend/admin-api`):**

7. `admin/auth/AdminAuthService.java` (632 lines — inner class `AdminAuthRepository`)

**Batch 3 — common ingestion (`backend/common`):**

8. `ingestion/IngestionRepository.java` (138 lines)

**Batch 4 — app-api consumer (`backend/app-api`):**

9. `service/AuthConsentSyncRepository.java` (596 lines)
10. `service/CaregiverInviteRepository.java` (681 lines)
11. `service/MentorRepository.java` (260 lines)
12. `service/ShareLandingRepository.java` (152 lines)
13. `service/DistributionRepository.java` (76 lines)
14. `service/ConversationSessionService.java` (92 lines — inline SQL)
15. `kg/KgAdminNotificationRepository.java` (95 lines)
16. `kg/KgContradictionRepository.java` (134 lines)
17. `kg/KgEntityRepository.java` (114 lines)
18. `kg/KgRelationshipRepository.java` (109 lines)
19. `palace/PalaceKeywordRepository.java` (157 lines)
20. `admin/config/AdminDataAccessConfiguration.java` (90 lines — wiring, admin-api)

---

## Key Observations

1. **No MyBatisPlus in any pom.xml yet** — must add dependency to `backend/pom.xml` dependencyManagement and to each module's pom.xml
2. **No Druid in any pom.xml** — must add `com.alibaba:druid-spring-boot-3-starter` (for Spring Boot 3.x)
3. **Complex SQL patterns present:**
   - CTEs (`with ... as`) in AdminMentorAuditReadRepository
   - Dynamic WHERE clauses (`StringBuilder` + `List<Object> args`) in multiple repos
   - Statement timeouts (`set local statement_timeout`) in admin read repos
   - pgvector operations in PalaceKeywordRepository
   - JSON serialization/deserialization in PalaceKeywordRepository
4. **Existing integration tests = parity tests** — AbstractIntegrationTest uses Testcontainers PostgreSQL; KgEntityRepositoryTest, KgContradictionRepositoryTest, PalaceKeywordRepositoryTest, etc. already test repo behavior
5. **Spring AI JdbcTemplate MUST remain** — PgVectorStore and JdbcChatMemoryRepository are framework-level and cannot be migrated

---

## Recommended Approach: MyBatisPlus XML Mapper Style

1. Add to `backend/pom.xml` dependencyManagement:
   ```xml
   <dependency>
     <groupId>com.baomidou</groupId>
     <artifactId>mybatis-plus-spring-boot3-starter</artifactId>
     <version>3.5.9</version>
   </dependency>
   <dependency>
     <groupId>com.alibaba</groupId>
     <artifactId>druid-spring-boot-3-starter</artifactId>
     <version>1.2.23</version>
   </dependency>
   <dependency>
     <groupId>cn.hutool</groupId>
     <artifactId>hutool-all</artifactId>
     <version>5.8.25</version>
   </dependency>
   ```

2. Use `@Mapper` interface + XML `<mapper>` files for all repositories
3. Use MyBatisPlus `BaseMapper<T>` for simple CRUD + `@SelectProvider`/`<script>` for dynamic SQL
4. Keep existing repository class facades (callers don't change) — implement each facade by injecting the new `@Mapper`
5. Configure Druid in `application.yml` with slow-query threshold

---

## Planned Tasks for S05

**T01: Add MyBatisPlus + Druid + Hutool dependencies + configure DataSource**

- `backend/pom.xml`: add 3 dependencies to dependencyManagement
- `backend/app-api/pom.xml`, `backend/admin-api/pom.xml`, `backend/common/pom.xml`: add as runtime dependencies
- `backend/app-api/src/main/resources/application.yml`: configure Druid datasource (url, username, password, slow-sql threshold)
- `backend/admin-api/src/main/resources/application.yml`: same Druid config
- Verify: `mvn -pl backend/app-api -am clean compile -q`

**T02: Batch 1 — migrate admin read-model (6 files in common)**

- Create mapper interfaces + XML files for: AdminRbac, AdminUserRead, AdminMentorAudit, AdminDistributionStats, AdminKnowledgeIngestion, AdminKnowledgeKg
- Replace JdbcTemplate in each repository class with @Mapper injection
- Handle statement timeout with MyBatis interceptor or `@Before` advice
- Verify: `mvn -pl backend/admin-api -am clean verify -q` (admin web tests pass)

**T03: Batch 2 + 3 — admin auth + common ingestion**

- Extract `AdminAuthRepository` inner class to standalone class
- Create mapper + XML for admin auth tables
- Create mapper + XML for ingestion tables
- Verify: `mvn -pl backend/admin-api -am clean verify -q`

**T04: Batch 4 — app-api consumer (11 files)**

- Create mappers + XML for: AuthConsentSync, CaregiverInvite, Mentor, ShareLanding, Distribution, ConversationSession, KgAdminNotification, KgContradiction, KgEntity, KgRelationship, PalaceKeyword
- PalaceKeywordRepository has pgvector + JSON — use `@SelectProvider` or raw `<script>` in XML
- Verify: `mvn -pl backend/app-api -am clean verify -q` (all existing repo tests pass = parity confirmed)

**T05: Runtime audit + final verification**

- Run audit script: `grep -rn "JdbcTemplate" backend/*/src/main --include="*.java"` — should only show Spring AI classes
- Verify Druid slow-query config is present in both application.yml files
- Run `mvn clean verify -q` across all modules
- Update `ci/k8s-smoke.sh` if needed

---

## Current State

S04 is complete (62 PASS smoke). S05 plan is researched but not started. The GSD slice S05 has NOT been planned yet via `gsd_plan_slice`.

## Next Session Resume Point

1. Call `gsd_plan_slice` for M007/S05 using the tasks above
2. Start with T01 (dependency setup) — this is safe to do without a live DB
3. T02–T05 require running integration tests (Testcontainers) — these need Docker to be running
