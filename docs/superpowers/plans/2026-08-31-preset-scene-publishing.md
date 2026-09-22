# Preset Scene Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a versioned preset-scene content store, admin draft/publish/rollback workflow, and public published catalog API.

**Architecture:** Keep `practice_spaces` and `practice_activities` as stable identities. Add immutable published versions plus one mutable draft per activity, expose mutations only through RBAC-protected admin services, and expose only current enabled published metadata to app clients.

**Tech Stack:** PostgreSQL 17, Flyway, Spring Boot 4.0.7, Java 17 bytecode, MyBatis, Spring Security, React 18, TypeScript 5.8, Ant Design 5, Vitest, Playwright.

**Spec:** `docs/superpowers/specs/2026-08-31-unified-scene-generation-household-profile-design.md`

## Global Constraints

- Execute this plan before `2026-08-31-unified-scene-generation-household-access.md` and `2026-08-31-mobile-unified-scene-experience.md`.
- Run `python3 tool/verify_spring_ai_2_backend_platform.py` and `cd backend && bash mvnw clean test` before Task 1; both must exit 0.
- Use Flyway version `V37`; update `DbMigrationApplication.EXPECTED_CURRENT_VERSION` from `36` to `37`.
- Production Jackson databind/core imports must use `tools.jackson.*`; `com.fasterxml.jackson.annotation.*` remains allowed.
- Use `OffsetDateTime` at DB/API boundaries and ISO 8601 JSON.
- Published rows are immutable; rollback always creates a new monotonically numbered published version.
- Public catalog responses never contain `generationBrief`, admin IDs, or audit details.
- Add exact permissions `practice:read`, `practice:write`, and `practice:publish`; grant them to `super_admin` in the migration.
- Do not include existing unrelated worktree changes or `mobile/windows/flutter/generated_*` files in task commits.

---

## File Structure

### Database ownership

- Create `backend/db-migration/src/main/resources/db/migration/V37__version_practice_preset_scenes.sql`: schema, five v1 published records, audit tables, RBAC seed, immutability triggers.
- Modify `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`: expected Flyway version.
- Modify `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`: clean install, upgrade, constraint, seed, and trigger coverage.

### Admin backend ownership

- Modify `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`: three permission definitions.
- Create `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneMapper.java`: MyBatis port.
- Create `backend/admin-api/src/main/resources/mapper/admin/AdminPresetSceneMapper.xml`: list, draft, publish, rollback, audit SQL.
- Create `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneRepository.java`: typed persistence facade.
- Create `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneService.java`: validation, versioning, transactions.
- Create `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneController.java`: REST and method-level permissions.
- Create `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminPresetSceneWebTest.java`: API/RBAC/concurrency behavior.

### Consumer catalog ownership

- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/preset/PresetSceneCatalogMapper.java`.
- Create `backend/app-api/src/main/resources/mapper/practice/PresetSceneCatalogMapper.xml`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/preset/PresetSceneCatalogService.java`.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogController.java`.
- Create `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogControllerTest.java`.

### Admin frontend ownership

- Create `admin-web/src/lib/presetScenesClient.ts`: typed HTTP client.
- Create `admin-web/src/pages/PresetScenesPage.tsx`: list, draft editor, history, publish, rollback.
- Modify `admin-web/src/app/routes.tsx`: route and permission allowlist.
- Create `admin-web/unit/lib/preset-scenes-client.test.ts`.
- Modify `admin-web/unit/app/access.test.ts`.
- Create `admin-web/tests/preset-scenes.spec.ts`.
- Modify `admin-web/tests/helpers/admin-api.ts`: API fixtures for E2E.

---

### Task 1: Add the versioned preset-scene schema

**Files:**
- Create: `backend/db-migration/src/main/resources/db/migration/V37__version_practice_preset_scenes.sql`
- Modify: `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`
- Modify: `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`

**Interfaces:**
- Consumes: existing `practice_spaces`, `practice_activities`, `admin_principals`, `admin_permissions`, `admin_role_permissions`.
- Produces: `practice_preset_scene_versions`, `practice_preset_scene_audit`, `practice_activities.current_published_version_id`, five published v1 scenes, three RBAC permissions.

- [ ] **Step 1: Add failing migration smoke assertions**

Add a `V37_PRESET_SCENE_SCHEMA` schema test that migrates to V36, applies V37, and asserts:

```java
assertThat(columnExists(jdbc, "practice_preset_scene_versions", "generation_brief")).isTrue();
assertThat(queryInt(jdbc, "select count(*) from practice_preset_scene_versions where state='published' and version=1"))
        .isEqualTo(5);
assertThat(queryInt(jdbc, "select count(*) from admin_permissions where permission_code like 'practice:%'"))
        .isEqualTo(3);
```

Add tests proving a second draft violates `uq_practice_preset_scene_versions_one_draft`, an update to an existing published row fails, and all five slugs exist: `bath_time`, `diaper_change`, `post_cry_soothing`, `feeding_time`, `bedtime`.

- [ ] **Step 2: Run the migration test and verify RED**

Run:

```bash
cd backend
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Expected: failure because Flyway V37 and its tables do not exist.

- [ ] **Step 3: Implement V37 schema and seed**

Create the migration with these essential shapes:

```sql
create table practice_preset_scene_versions (
    version_id bigserial primary key,
    activity_id bigint not null,
    version integer null,
    state varchar(16) not null,
    title_zh varchar(120) not null,
    summary_zh varchar(240) not null,
    scene_tag_en varchar(120) not null,
    coach_tip_zh varchar(240) not null,
    sort_order integer not null,
    generation_brief varchar(1200) not null,
    enabled boolean not null,
    lock_version integer not null default 0,
    created_by_admin_id varchar(64) null,
    published_by_admin_id varchar(64) null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    published_at timestamp with time zone null,
    constraint fk_practice_preset_scene_versions_activity
        foreign key (activity_id) references practice_activities(id),
    constraint fk_practice_preset_scene_versions_created_by
        foreign key (created_by_admin_id) references admin_principals(principal_id),
    constraint fk_practice_preset_scene_versions_published_by
        foreign key (published_by_admin_id) references admin_principals(principal_id),
    constraint chk_practice_preset_scene_versions_state
        check (state in ('draft', 'published')),
    constraint chk_practice_preset_scene_versions_number
        check ((state='draft' and version is null and published_at is null)
            or (state='published' and version > 0 and published_at is not null)),
    constraint chk_practice_preset_scene_versions_lock
        check (lock_version >= 0)
);

create unique index uq_practice_preset_scene_versions_published
    on practice_preset_scene_versions(activity_id, version)
    where state='published';

create unique index uq_practice_preset_scene_versions_one_draft
    on practice_preset_scene_versions(activity_id)
    where state='draft';
```

Add `practice_preset_scene_audit`, `current_published_version_id`, a trigger that blocks updates/deletes when `OLD.state='published'`, and a deferred constraint trigger proving the current pointer references a published version for the same activity. Insert missing `post_cry_soothing` activity before seeding five v1 versions. Add the three RBAC rows and grant them to `super_admin`.

- [ ] **Step 4: Raise the expected Flyway version**

Change:

```java
static final String EXPECTED_CURRENT_VERSION = "37";
```

- [ ] **Step 5: Run migration tests and verify GREEN**

Run the command from Step 2. Expected: exit 0, including duplicate-draft and immutable-published checks.

- [ ] **Step 6: Commit Task 1**

```bash
git add backend/db-migration
git commit -m "feat(db): version preset scene content"
```

---

### Task 2: Add admin permissions and persistence ports

**Files:**
- Modify: `backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java`
- Create: `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneMapper.java`
- Create: `backend/admin-api/src/main/resources/mapper/admin/AdminPresetSceneMapper.xml`
- Create: `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneRepository.java`
- Test: `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminPresetSceneWebTest.java`

**Interfaces:**
- Consumes: V37 schema.
- Produces: `AdminPresetSceneRepository` methods used by Task 3.

- [ ] **Step 1: Write failing permission and repository tests**

Assert the permission catalog returns these exact codes:

```java
assertThat(catalog.codes()).contains(
        "practice:read",
        "practice:write",
        "practice:publish"
);
```

In the web test fixture, use repository-backed setup to assert `findScenes()` returns current published version plus optional draft lock version.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend
bash mvnw -pl admin-api -Dtest=AdminPresetSceneWebTest,AdminRbacWebTest test
```

Expected: compilation failure because practice permission constants and repository types do not exist.

- [ ] **Step 3: Add permission definitions**

Add constants and definitions:

```java
public static final String PRACTICE_READ = "practice:read";
public static final String PRACTICE_WRITE = "practice:write";
public static final String PRACTICE_PUBLISH = "practice:publish";
```

- [ ] **Step 4: Add typed persistence interfaces**

Define these repository methods exactly:

```java
public interface AdminPresetSceneRepository {
    List<SceneSummaryRow> findScenes();
    Optional<SceneDetailRow> findScene(String presetSceneId);
    Optional<DraftRow> findDraftForUpdate(String presetSceneId);
    DraftRow createDraft(String presetSceneId, DraftWrite write, String adminId, OffsetDateTime now);
    DraftRow updateDraft(String presetSceneId, int expectedLockVersion, DraftWrite write, String adminId, OffsetDateTime now);
    PublishedRow publish(String presetSceneId, int expectedLockVersion, String adminId, OffsetDateTime now);
    DraftRow copyPublishedToDraft(String presetSceneId, int sourceVersion, String adminId, OffsetDateTime now);
    List<PublishedRow> findVersions(String presetSceneId);
}
```

Use mapper XML for row locking, optimistic `where lock_version = #{expectedLockVersion}`, monotonic `max(version)+1`, pointer update, and audit insert. Keep multi-statement publish orchestration in the repository/service transaction, not a stored procedure.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: exit 0.

- [ ] **Step 6: Commit Task 2**

```bash
git add backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice backend/admin-api/src/main/resources/mapper/admin
git commit -m "feat(admin): add preset scene persistence"
```

---

### Task 3: Implement admin draft, publish, history, and rollback APIs

**Files:**
- Create: `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneService.java`
- Create: `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice/AdminPresetSceneController.java`
- Modify: `backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminPresetSceneWebTest.java`

**Interfaces:**
- Consumes: `AdminPresetSceneRepository` from Task 2.
- Produces: `/api/admin/v1/practice/preset-scenes` API used by Task 5.

- [ ] **Step 1: Add failing API/RBAC tests**

Cover:

```java
mockMvc.perform(put("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
        .header(HttpHeaders.AUTHORIZATION, bearer(editorToken))
        .contentType(MediaType.APPLICATION_JSON)
        .content(validDraftJson(0)))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.lockVersion").value(1));
```

Also assert read-only admins cannot write, writers cannot publish, publishers can publish, stale `lockVersion` returns `409 practice_draft_version_conflict`, invalid brief returns `422 practice_publish_validation_failed`, published versions remain unchanged, rollback creates version `current+1`, and every create/update/publish/disable/rollback action writes one audit row with the authenticated admin principal.

- [ ] **Step 2: Run the focused web test and verify RED**

```bash
cd backend
bash mvnw -pl admin-api -Dtest=AdminPresetSceneWebTest test
```

Expected: 404 or compilation failure because controller/service do not exist.

- [ ] **Step 3: Implement validation and service transactions**

Use these command records:

```java
public record DraftCommand(
        String title,
        String summary,
        String sceneTag,
        String coachTip,
        int sortOrder,
        String generationBrief,
        boolean enabled,
        int lockVersion
) {}

public record PublishCommand(int lockVersion) {}
```

Normalize text, require title/summary/tag/coach tip/brief, cap brief at 1200 characters, reject phone-like sequences and control characters, and map optimistic update count 0 to `practice_draft_version_conflict`.

- [ ] **Step 4: Implement method-level RBAC controller**

Use exact authorities:

```java
@GetMapping
@PreAuthorize("hasAuthority('practice:read')")

@PutMapping("/{presetSceneId}/draft")
@PreAuthorize("hasAuthority('practice:write')")

@PostMapping("/{presetSceneId}/publish")
@PreAuthorize("hasAuthority('practice:publish')")

@PostMapping("/{presetSceneId}/rollback/{version}")
@PreAuthorize("hasAuthority('practice:publish')")
```

Read admin principal ID from `JwtAuthenticationToken`, never from the request body.

- [ ] **Step 5: Run web tests and verify GREEN**

Run Step 2 command. Expected: exit 0 with RBAC, conflict, publication, and rollback assertions passing.

- [ ] **Step 6: Commit Task 3**

```bash
git add backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminPresetSceneWebTest.java
git commit -m "feat(admin): publish preset scene versions"
```

---

### Task 4: Expose the current published consumer catalog

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/preset/PresetSceneCatalogMapper.java`
- Create: `backend/app-api/src/main/resources/mapper/practice/PresetSceneCatalogMapper.xml`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/preset/PresetSceneCatalogService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogController.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogControllerTest.java`

**Interfaces:**
- Consumes: V37 current-published pointer.
- Produces: `PresetSceneCatalogService.requirePublished(String)` for Plan 2 and `GET /api/v1/practice/preset-scenes` for Plan 3.

- [ ] **Step 1: Write failing catalog contract tests**

Assert exact response keys and ordering:

```java
mockMvc.perform(get("/api/v1/practice/preset-scenes")
        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$[0].presetSceneId").value("bath_time"))
    .andExpect(jsonPath("$[0].publishedVersion").value(1))
    .andExpect(jsonPath("$[0].generationBrief").doesNotExist());
```

Publish a disabled version and assert it disappears. Publish a changed title and assert the current response changes while history remains.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
cd backend
bash mvnw -pl app-api -Dtest=PresetSceneCatalogControllerTest test
```

Expected: 404 because endpoint does not exist.

- [ ] **Step 3: Implement mapper and service**

Expose these types:

```java
public record PublishedPresetScene(
        long activityId,
        long versionId,
        int publishedVersion,
        String presetSceneId,
        String spaceId,
        String title,
        String summary,
        String sceneTag,
        String coachTip,
        int sortOrder,
        String generationBrief
) {}

public List<PublishedPresetScene> listPublished();
public PublishedPresetScene requirePublished(String presetSceneId);
```

The controller maps to a public DTO that omits `activityId`, `versionId`, and `generationBrief`.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run Step 2 command. Expected: exit 0.

- [ ] **Step 5: Commit Task 4**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/preset backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogController.java backend/app-api/src/main/resources/mapper/practice/PresetSceneCatalogMapper.xml backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogControllerTest.java
git commit -m "feat(api): expose published preset scenes"
```

---

### Task 5: Build the admin-web preset-scene workbench

**Files:**
- Create: `admin-web/src/lib/presetScenesClient.ts`
- Create: `admin-web/src/pages/PresetScenesPage.tsx`
- Modify: `admin-web/src/app/routes.tsx`
- Create: `admin-web/unit/lib/preset-scenes-client.test.ts`
- Modify: `admin-web/unit/app/access.test.ts`
- Create: `admin-web/tests/preset-scenes.spec.ts`
- Modify: `admin-web/tests/helpers/admin-api.ts`

**Interfaces:**
- Consumes: Task 3 admin API.
- Produces: `/practice/preset-scenes` admin route.

- [ ] **Step 1: Write failing client and route tests**

Define expected client shape:

```ts
export type PresetSceneDraftWrite = {
  title: string;
  summary: string;
  sceneTag: string;
  coachTip: string;
  sortOrder: number;
  generationBrief: string;
  enabled: boolean;
  lockVersion: number;
};
```

Assert the route requires `practice:read`, an editor sees save but not publish without `practice:publish`, and the client sends `lockVersion` unchanged.

- [ ] **Step 2: Run unit tests and verify RED**

```bash
pnpm --filter admin-web test -- preset-scenes-client access
```

Expected: missing module/route failures.

- [ ] **Step 3: Implement the typed client and route**

Add the three permissions to `ADMIN_ROUTE_PERMISSION_CODES`, add route key `preset-scenes`, lazy-load `PresetScenesPage`, and register:

```tsx
{
  key: 'preset-scenes',
  path: '/practice/preset-scenes',
  title: 'Preset Scenes',
  description: '预置场景草稿、发布版本与回滚。',
  icon: <FormOutlined />,
  requiredPermissions: ['practice:read'],
  navVisibility: 'primary',
  defaultLandingWeight: 65,
  testId: 'workspace-link-preset-scenes',
  component: PresetScenesPage,
}
```

- [ ] **Step 4: Implement the page**

Use one ProTable for scene summaries, a Drawer Form for the unique draft, and a version-history Modal. Disable save without `practice:write`; disable publish/rollback without `practice:publish`. On `practice_draft_version_conflict`, reload the selected scene and keep the user's unsaved values visible for comparison.

- [ ] **Step 5: Run unit tests and verify GREEN**

Run Step 2 command. Expected: exit 0.

- [ ] **Step 6: Add E2E coverage**

Cover list, edit/save, stale conflict, publish, disabled scene, history, rollback, and RBAC visibility in `preset-scenes.spec.ts`.

Run:

```bash
pnpm --filter admin-web test:e2e -- preset-scenes.spec.ts
```

Expected: all preset-scene cases pass.

- [ ] **Step 7: Commit Task 5**

```bash
git add admin-web/src/lib/presetScenesClient.ts admin-web/src/pages/PresetScenesPage.tsx admin-web/src/app/routes.tsx admin-web/unit admin-web/tests
git commit -m "feat(admin-web): manage preset scenes"
```

---

### Task 6: Verify Plan 1 as an independently deployable slice

**Files:**
- Modify, only if verification exposes a defect: files listed in Tasks 1-5.

**Interfaces:**
- Produces: published content management and public catalog required by Plans 2 and 3.

- [ ] **Step 1: Run backend verification**

```bash
cd backend
bash mvnw -pl db-migration,common,admin-api,app-api -am clean test
```

Expected: exit 0.

- [ ] **Step 2: Run admin-web verification**

```bash
pnpm --filter admin-web typecheck
pnpm --filter admin-web test
pnpm --filter admin-web build
```

Expected: all commands exit 0.

- [ ] **Step 3: Inspect schema and response privacy**

Run the focused catalog/admin integration tests and assert response bodies contain neither `generationBrief` on consumer APIs nor admin IDs/audit payloads.

- [ ] **Step 4: Commit only verification fixes, if any**

```bash
git add backend/db-migration/src/main/resources/db/migration/V37__version_practice_preset_scenes.sql backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java backend/common/src/main/java/com/zhangspaghetti/babytalk/admin/rbac/AdminPermissionCatalog.java backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/practice backend/admin-api/src/main/resources/mapper/admin/AdminPresetSceneMapper.xml backend/admin-api/src/test/java/com/zhangspaghetti/babytalk/admin/web/AdminPresetSceneWebTest.java backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/preset backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogController.java backend/app-api/src/main/resources/mapper/practice/PresetSceneCatalogMapper.xml backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PresetSceneCatalogControllerTest.java admin-web/src/lib/presetScenesClient.ts admin-web/src/pages/PresetScenesPage.tsx admin-web/src/app/routes.tsx admin-web/unit/lib/preset-scenes-client.test.ts admin-web/unit/app/access.test.ts admin-web/tests/preset-scenes.spec.ts admin-web/tests/helpers/admin-api.ts
git commit -m "test(practice): verify preset publishing"
```

Skip this commit when verification required no file changes.
