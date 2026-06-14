---
phase: "15"
plan: "05"
---

# T05: Added module-local Flyway Maven CLI proof, V16-aligned schema assertions, and root worktree Flutter test wiring for gate verification.

**Added module-local Flyway Maven CLI proof, V16-aligned schema assertions, and root worktree Flutter test wiring for gate verification.**

## What Happened

本任务先在 `backend/db-migration/pom.xml` 补上 `flyway-maven-plugin`，明确把 migration source 固定到 module-local `classpath:db/migration`，并让数据库连接只从命令行 `-Dflyway.*`/环境注入，不把 schema ownership 回退到 `app-api` 或 `admin-api`。随后把 `DbMigrationApplication` 与 `DbMigrationSmokeTest` 收口到同一组 schema closure 常量：`currentVersion=16`、`appliedCount=14`，并在 smoke proof 中补上 `account_refresh_tokens` 的存在性断言，这样 runtime proof 和 fresh-DB proof 不会再因为只改一侧而漂移。执行期间还复现了 gate 报的 Flutter 失败，确认根因不是 mobile 功能回归，而是 worktree 根目录的 `flutter test mobile/test/...` 会按根 `pubspec.yaml` 的包上下文编译；为此我仅在根 `pubspec.yaml` 增补 Flutter SDK / `flutter_test` / `mobile` path dependency，让 gate 的根目录命令能正确加载 `package:mobile/...`，未改动 mobile 业务实现。`app-api` 与 `admin-api` 的 `spring.flyway.enabled=false` 保持不变，并通过复跑 S02 的 app-api/mobile 验证面确认 JWT + Bearer 行为仍然成立。

## Verification

已按任务计划与 slice 验证面重放关键命令：1) `docker compose up -d postgres` 成功，15432 本地 Postgres 可用；2) `./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` 成功，module-local CLI path 可独立执行；3) `./backend/mvnw -f backend/db-migration/pom.xml flyway:info ...` 输出 `Schema version: 16`，确认 V16 已被 CLI owner 识别；4) `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` 通过，日志显示 `currentVersion=16, appliedCount=14`；5) 作为 final task 额外重放 slice 级验证：`JwtTokenLifecycleWebTest`、`AuthConsentSyncWebTest`、`MentorWebTest` 联合通过，观察到预期 auth failure logs（如 `rotated` / `revoked` / `session_invalid`）；6) `flutter test mobile/test/features/account/jwt_session_refresh_test.dart` 通过，确认单次 refresh/replay seam 仍成立；7) gate 失败的 `flutter test mobile/test/features/household/household_repository_test.dart mobile/test/features/mentor/mentor_view_model_test.dart` 在根目录上下文下现已通过；8) 负向验证也已确认：缺失 Flyway DB 参数会直接报 `Configure the url, user and password!`，错误 locations 会直接报 `Unable to resolve location classpath:missing`，符合 fail-fast 预期。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `docker compose up -d postgres` | 0 | ✅ pass | 1161ms |
| 2 | `./backend/mvnw -f backend/db-migration/pom.xml -q flyway:migrate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` | 0 | ✅ pass | 6068ms |
| 3 | `./backend/mvnw -f backend/db-migration/pom.xml flyway:info -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk` | 0 | ✅ pass | 6184ms |
| 4 | `./backend/mvnw -f backend/pom.xml -q -pl db-migration -am test -Dtest=DbMigrationSmokeTest` | 0 | ✅ pass | 14739ms |
| 5 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest=JwtTokenLifecycleWebTest,AuthConsentSyncWebTest,MentorWebTest` | 0 | ✅ pass | 28930ms |
| 6 | `flutter test mobile/test/features/account/jwt_session_refresh_test.dart` | 0 | ✅ pass | 8249ms |
| 7 | `flutter test mobile/test/features/household/household_repository_test.dart mobile/test/features/mentor/mentor_view_model_test.dart` | 0 | ✅ pass | 7499ms |
| 8 | `./backend/mvnw -f backend/db-migration/pom.xml -q flyway:info` | 1 | ✅ pass (expected fail-fast) | 5598ms |
| 9 | `./backend/mvnw -f backend/db-migration/pom.xml -q flyway:validate -Dflyway.url=jdbc:postgresql://localhost:15432/babytalk -Dflyway.user=babytalk -Dflyway.password=babytalk -Dflyway.locations=classpath:missing` | 1 | ✅ pass (expected fail-fast) | 5501ms |

## Deviations

补了一个小范围验证适配：更新 worktree 根 `pubspec.yaml`，让根目录执行 `flutter test mobile/test/...` 时具备 Flutter + `mobile` path dependency 上下文。这个改动只服务于 gate/工作树根级测试入口，不改变 mobile 业务代码或测试语义。

## Known Issues

None.

## Files Created/Modified

- `backend/db-migration/pom.xml`
- `backend/db-migration/src/main/java/com/zhangspaghetti/babytalk/migration/DbMigrationApplication.java`
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
- `pubspec.yaml`
