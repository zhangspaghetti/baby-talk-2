# Contributing to Baby Talk 2

本文面向第一次进入仓库的工程师。读完后，你应该知道：**先跑哪条 front-door 命令、该改哪个模块、以及在请求 review 之前该走哪一级 verification**。

## Start with the right front door

- 想把整套 Helm baseline 拉起来：`dev-up-helm-demo`
- 想复用 live stack 跑最小 smoke：`dev-verify-helm-demo`
- 想跑当前 S01 的 CI-equivalent gate：`bash ci/k8s-smoke.sh`
- 想直接执行本地 Helm front-door verifier：`dart run tool/verify_m007_s01_helm_baseline.dart demo`

除 `bash ci/k8s-smoke.sh` 这条 CI-equivalent gate 之外，其余 repo-root verifier 都是 scoped drill-down；不要再拼 ad-hoc shell chain。

这些入口会围绕 `tmp/m007-s01-helm-metrics.jsonl` 提供 bounded local history。wrapper 或 smoke 失败时，先看 stdout 里的 `first_failure_stage` / `likely_cause` / `next_action`，再决定要不要继续下钻更重的 gate。

## Everyday workflows

### Full-stack admin change

1. 先拉起 Helm baseline：
   - POSIX：`./scripts/dev-up-helm-demo.sh`
   - Windows：`scripts\dev-up-helm-demo.cmd`
2. 修改 `admin-web` / `admin-api` / `common` / `db-migration` 中与你的变更直接相关的模块。
3. 跑最小 smoke：
   - POSIX：`./scripts/dev-verify-helm-demo.sh`
   - Windows：`scripts\dev-verify-helm-demo.cmd`
4. 如果 smoke 还不足以解释问题，再跑 `bash ci/k8s-smoke.sh` 或 `dart run tool/verify_m007_s01_helm_baseline.dart demo`。

### Backend-only change

优先方案仍然是直接跑前门：

```bash
./scripts/dev-up-helm-demo.sh
```

如果你已经有 kind 集群，只想重放 release 级别安装，则使用：

```bash
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -f deploy/helm/babytalk-infra/values-kind.yaml --namespace babytalk --create-namespace --wait --timeout 120s
helm upgrade --install babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-kind.yaml --namespace babytalk --create-namespace --wait --timeout 180s
```

在 backend-only 路径下，优先证明：

- `db-migration` 仍然是 schema owner
- `app-api` 与 `admin-api` 的 contract 没有被你的改动破坏
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
   - `./scripts/dev-up-helm-demo.sh`
   - `scripts\dev-up-helm-demo.cmd`
2. **repo-root fast smoke**
   - `./scripts/dev-verify-helm-demo.sh`
   - `scripts\dev-verify-helm-demo.cmd`
3. **CI-equivalent Helm smoke**
   - `bash ci/k8s-smoke.sh`
4. **direct verifier invocation**
   - `dart run tool/verify_m007_s01_helm_baseline.dart demo`
   - `dart run tool/verify_m007_s01_helm_baseline.dart smoke`
5. **module-local checks**
   - `./backend/mvnw -f backend/pom.xml test -DexcludedGroups=llm-it`
   - `bash ci/backend-test.sh`
   - `npm --prefix admin-web run build`
   - `flutter test`

front-door 改动收尾时，不只要看命令 exit code；还要确认 shared telemetry history `tmp/m007-s01-helm-metrics.jsonl` 里出现 recent `demo` + `smoke` entries。

如果你的改动影响 README、runbook、wrapper、repo-root verification 入口或 CI handoff，**至少**把 `./scripts/dev-up-helm-demo.sh`、`./scripts/dev-verify-helm-demo.sh` 与 `bash ci/k8s-smoke.sh` 纳入 verification。

## Module boundaries

| Module | 负责什么 | 不负责什么 |
| --- | --- | --- |
| `backend/app-api` | mobile / consumer HTTP API | admin browser surface |
| `backend/admin-api` | admin auth + admin data contracts | repo-root gateway front door |
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
