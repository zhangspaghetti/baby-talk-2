# Contributing to Baby Talk 2

本文面向第一次进入仓库的工程师。读完后，你应该知道：**先跑哪条 front-door 命令、该改哪个模块、以及在请求 review 之前该走哪一级 verification**。

## Start with the right front door

- 想把整套 admin demo 拉起来：`dev-up-admin-demo`
- 想复用 live stack 跑最小 smoke：`dev-verify-admin-demo`
- 想继续下钻 control-plane/auth proof：`dart run tool/verify_m006_s12_control_plane_freshness.dart`
- 想跑最终 release closure（CI 同款）：`dart run tool/verify_m006_s14_release_closure.dart`
- 想只 debug 某个 deploy/runtime 子面：`dart run tool/verify_m006_s08_release.dart --runtime` / `--helm`

这两条 repo-root wrapper 会共享 `tmp/m006-s13-front-door-metrics.jsonl` 这份 bounded local history；先看 stdout 里的 `telemetry_path` / `smoke_recent_pass_rate` / `first_failure_hotspot`，再决定要不要继续下钻更重的 verifier。

## Everyday workflows

### Full-stack admin change

1. 先拉起 demo：
   - POSIX：`./scripts/dev-up-admin-demo.sh`
   - Windows：`scripts\dev-up-admin-demo.cmd`
2. 修改 `admin-web` / `admin-api` / `common` / `db-migration` 中与你的变更直接相关的模块。
3. 跑最小 smoke：
   - POSIX：`./scripts/dev-verify-admin-demo.sh`
   - Windows：`scripts\dev-verify-admin-demo.cmd`
4. 如果 smoke 暗示 control-plane/auth drift，再跑 `dart run tool/verify_m006_s12_control_plane_freshness.dart`。

### Backend-only change

```bash
docker compose up -d postgres minio db-migration
./backend/mvnw -f backend/pom.xml -pl app-api -am spring-boot:run
./backend/mvnw -f backend/pom.xml -pl admin-api -am spring-boot:run -Dspring-boot.run.arguments=--server.port=8081
```

在 backend-only 路径下，优先证明：

- `db-migration` 仍然是 schema owner
- `app-api` 与 `admin-api` 都能在 split runtime 下健康启动
- 新 contract 没有把管理员能力错误地下沉到 mobile/client surface

### admin-web-only change

```bash
npm --prefix admin-web install
npm --prefix admin-web run dev
npm --prefix admin-web run build
```

默认代理目标是本地 `admin-api`。如果你换了端口，先设置 `VITE_ADMIN_API_PROXY_TARGET`。

### mobile change

```bash
cd mobile
flutter pub get
flutter test
flutter run
```

`mobile` 只连 `app-api`，不要把 `admin-api` 当成 mobile contract。

## verification ladder

按成本从低到高选择 verification，而不是一上来就跑最重的链路。

1. **front door truth**
   - `dart run tool/verify_m006_s13_demo_path.dart`
2. **repo-root fast smoke**
   - `./scripts/dev-verify-admin-demo.sh`
   - `scripts\dev-verify-admin-demo.cmd`
3. **Overview / auth proof pack**
   - `dart run tool/verify_m006_s12_control_plane_freshness.dart`
4. **final release closure (CI 同款)**
   - `dart run tool/verify_m006_s14_release_closure.dart`
5. **scoped deploy/runtime debug**
   - `dart run tool/verify_m006_s08_release.dart --runtime`
   - `dart run tool/verify_m006_s08_release.dart --helm`
6. **module-local checks**
   - `./backend/mvnw -f backend/pom.xml test -DexcludedGroups=llm-it`
   - `npm --prefix admin-web run build`
   - `flutter test`

front-door 改动收尾时，不只要看命令 exit code；还要确认 shared telemetry history `tmp/m006-s13-front-door-metrics.jsonl` 里出现 recent `demo` + `smoke` entries。机械化检查命令保留在 S13 runbook。

如果你的改动影响 README、runbook、wrapper、repo-root verification 入口或 CI handoff，**必须**把 `dart run tool/verify_m006_s13_demo_path.dart` 与 `dart run tool/verify_m006_s14_release_closure.dart` 都加入 verification。

## Module boundaries

| Module | 负责什么 | 不负责什么 |
| --- | --- | --- |
| `backend/app-api` | mobile / consumer HTTP API | admin browser surface |
| `backend/admin-api` | admin auth + admin data contracts | 对外 public ingress |
| `backend/db-migration` | schema migration | 持续 serving traffic |
| `admin-web` | 管理后台 UI 与 `/api/admin/**` 代理前门 | 存储 bootstrap secrets、直连数据库 |
| `mobile` | 面向家长/照护者的 Flutter 客户端 | 管理后台能力 |
| `tool/` | repo-root proof packs / verifiers | 长期业务逻辑 |
| `docs/runbooks/` | operator / release / front-door truth | 替代可执行脚本 |

## Review-ready checklist

- 我只改了与任务直接相关的模块，没有顺手重构旁边的代码。
- 我用对了 front-door wrapper 或 verifier，而不是重新发明一条私有命令链。
- 我没有在文档、日志或截图里打印 JWT、bootstrap password、refresh token，或 public admin-api URL。
- 我已经记录最相关的 verification 证据，而不是只说“本地测过”。
- 如果 front door 发生变化，我同步更新了 `README.md`、`CONTRIBUTING.md` 或对应 runbook。
