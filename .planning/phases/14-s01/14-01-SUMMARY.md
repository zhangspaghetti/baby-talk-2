---
phase: "14"
plan: "01"
---

# T01: 将 backend 改为四模块 Maven reactor，并把现有单体源码/测试整体平移到 app-api，补齐 AppApi/AdminApi 启动入口。

**将 backend 改为四模块 Maven reactor，并把现有单体源码/测试整体平移到 app-api，补齐 AppApi/AdminApi 启动入口。**

## What Happened

我先把 `backend/pom.xml` 从单模块 Spring Boot 应用改成 reactor parent/aggregator，声明 `common` / `app-api` / `admin-api` / `db-migration` 四个子模块，并把原有 Spring Boot parent、Java 版本和 Spring AI BOM 上提到父 POM。随后将整棵 `backend/src` 平移到 `backend/app-api/src`，保留 `com.zhangspaghetti.babytalk` 包路径不变，避免 controller/service/repository wiring 和测试包扫描发生无谓重命名。原入口类改名为 `AppApiApplication` 并继续放在根包下，让现有 `@SpringBootTest` 在迁移后仍能自动发现新的 `@SpringBootConfiguration`，不需要批量修改测试注解。\n\n在模块边界上，我刻意没有把现有 domain/service/repository 抽进 `common`；`common` 目前只作为薄边界占位，`app-api` 继续承载全部现有 runtime 代码和测试，`admin-api` 与 `db-migration` 只建立可编译骨架。这符合本任务“先退休模块拓扑风险，再让后续 migration/auth/browser proof 叠加”的目标。为此我为 `app-api` 单独写回了原有依赖集合和 surefire/Testcontainers 环境配置，确保 Docker/Testcontainers/Flyway 行为不因模块重排而改变；同时新增 `AdminApiApplication` 和相应 POM，让 admin 侧已经具备独立 Boot 入口。\n\n验证阶段先直接执行任务合同里的 `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test`，确认新路径下 `AuthConsentSyncWebTest`、`MentorWebTest`、`IngestionControllerTest` 以及其余 app-api 测试都由 `AppApiApplication` 成功带起。随后我额外验证了 `admin-api` / `db-migration` 骨架能在 reactor 下独立解析与编译，并通过打包后的 `admin-api` jar 真正启动进程、直接请求 `/actuator/health` 拿到 `200 {"status":"UP"}`。在探针过程中我发现 `spring-boot:run -pl admin-api -am` 从 reactor 根目录执行时，CLI goal 会落到父 `pom` 上而不是子模块，因此最终采用“先 reactor 打包、再直接运行子模块 jar”的方式完成独立 health 证明。

## Verification

已完成以下验证：\n\n1. 运行任务合同命令 `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test`，命令成功返回；日志中多次明确显示 `Found @SpringBootConfiguration com.zhangspaghetti.babytalk.AppApiApplication`，证明 `app-api` 上下文装配成功且模块级失败会定位到新入口。\n2. 审计 `backend/app-api/target/surefire-reports`：共生成 66 份 XML 报告，累计 275 个测试，`failures=0`、`errors=0`、`skipped=0`；并确认 `AuthConsentSyncWebTest`、`MentorWebTest`、`IngestionControllerTest` 的 surefire 报告均来自新模块路径。\n3. 运行 `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api,db-migration -am test -DskipTests`，确认新建的 `admin-api` / `db-migration` skeleton 在 reactor 中可解析、可编译。\n4. 运行 `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am package -DskipTests` 生成 `admin-api` 可执行 jar，随后启动 `backend/admin-api/target/admin-api-0.0.1-SNAPSHOT.jar` 并请求 `http://127.0.0.1:18081/actuator/health`，返回 `200 {"status":"UP"}`，证明 `admin-api` 已具备独立可启动的 health probe 基线。\n\n本任务作为中间任务，slice 级验证目前已部分推进：`admin-api` 独立 health probe 已可直接检查；`app-api` 直接 runtime health、`db-migration` 独立日志/退出码、admin auth 的 401/credential failure contract、以及 browser login error state 仍留给后续任务完成。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test` | 0 | ✅ pass | 131000ms |
| 2 | `python - <<'PY' # summarize backend/app-api/target/surefire-reports XML totals\nPY` | 0 | ✅ pass | 48ms |
| 3 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api,db-migration -am test -DskipTests` | 0 | ✅ pass | 3885ms |
| 4 | `backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am package -DskipTests` | 0 | ✅ pass | 4177ms |
| 5 | `GET http://127.0.0.1:18081/actuator/health (against packaged admin-api jar)` | 0 | ✅ pass | 221ms |

## Deviations

为拿到 `admin-api` 的直接 health 证据，我没有继续使用 `spring-boot:run -pl admin-api -am` 作为探针方式，因为该 CLI goal 在 reactor 根目录会绑定到父 `pom` 并报“Unable to find a suitable main class”。我改为先用 reactor 打包，再直接运行 `admin-api` 产物 jar 完成验证。源码拆分目标与模块边界未偏离任务计划。

## Known Issues

无阻塞性问题。按计划仍待后续任务完成的事项包括：将 Flyway 职责从 `app-api` 迁到 `db-migration`、补齐 admin auth 失败契约，以及交付 browser login error state 证明。

## Files Created/Modified

- `backend/pom.xml`
- `backend/common/pom.xml`
- `backend/app-api/pom.xml`
- `backend/admin-api/pom.xml`
- `backend/db-migration/pom.xml`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/AppApiApplication.java`
- `backend/admin-api/src/main/java/com/zhangspaghetti/babytalk/admin/AdminApiApplication.java`
- `backend/app-api/src/main/resources/application.yml`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/AuthConsentSyncWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/ingestion/IngestionControllerTest.java`
