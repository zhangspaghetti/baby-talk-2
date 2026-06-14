---
phase: "21"
plan: "03"
---

# T03: 将 Helm chart 改写为显式的 app-api/admin-api/admin-web 三个 workload 与 pre-install/pre-upgrade db-migration hook，并让 admin-web 代理跟随 chart 内部 service truth。

**将 Helm chart 改写为显式的 app-api/admin-api/admin-web 三个 workload 与 pre-install/pre-upgrade db-migration hook，并让 admin-web 代理跟随 chart 内部 service truth。**

## What Happened

我把 `deploy/helm/babytalk` 从单 deployment/service 结构改成了显式 split-stack chart：`app-api`、`admin-api`、`admin-web` 各自拥有独立的 Deployment/Service，`db-migration` 变成唯一的 pre-install / pre-upgrade hook Job。values 也同步拆成四个 surface 的镜像、replica、service、ingress 与 probe 配置，不再默认回落到旧的 `babytalk/backend` 单体镜像假设。

为了让 chart 自己说真话，我补齐了共享 ConfigMap/Secret contract，把 app-api / admin-api 运行时真正读取的 consumer/admin auth、embedding、MinIO、knowledge-ops 相关 env 都显式写进模板；对必须存在但允许空字符串的 dev-only key 改用 `hasKey`/`fail`，避免 production values 因为空字符串误报。`admin-web` 的 nginx upstream 不再依赖 compose DNS，而是由 Helm helper 生成并通过独立 ConfigMap 挂载，稳定指向 chart-managed `admin-api` Service。为清掉辅助产物里的旧单 service 假设，我一并更新了 `templates/NOTES.txt` 和 `templates/tests/test-connection.yaml`，让 port-forward 指引与 Helm test 都围绕显式 component 名称工作。

## Verification

本任务的 chart 级验证已通过：`helm lint deploy/helm/babytalk`、`helm lint ... -f values-production.yaml`、默认值与 production 值的 `helm template ... | rg "app-api|admin-api|admin-web|db-migration"` 全部为绿，说明四个 surface 都能被稳定渲染。`bash ci/k8s-smoke.sh` 也通过，确认 lint/template/kubectl dry-run/Helm test template/runbook 在当前 chart 上仍然成立。CI wiring grep 仍然能找到 `setup-node`、`playwright install chromium --with-deps`、`2375` relay、`playwright-report` artifact 和 `verify_m006_s08_release` 调用。

slice 级 repo-root verifier 仍未全绿：`dart run tool/verify_m006_s08_release.dart` 在 `Runtime | canonical admin browser proof pack` 阶段失败，落点仍是现有 `admin-web/tests/knowledge-ops.spec.ts:299` 的 polling 断言（expected 11, received 13），HTML 报告输出在 `admin-web/playwright-report/index.html`。这与本次 Helm chart 改写无直接关系，但它意味着整个 S08 的总验证门还未关闭。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `helm lint deploy/helm/babytalk` | 0 | ✅ pass | 398ms |
| 2 | `helm lint deploy/helm/babytalk -f deploy/helm/babytalk/values-production.yaml` | 0 | ✅ pass | 233ms |
| 3 | `helm template babytalk deploy/helm/babytalk | rg -n "app-api|admin-api|admin-web|db-migration" >/dev/null` | 0 | ✅ pass | 345ms |
| 4 | `helm template babytalk deploy/helm/babytalk -f deploy/helm/babytalk/values-production.yaml | rg -n "app-api|admin-api|admin-web|db-migration" >/dev/null` | 0 | ✅ pass | 323ms |
| 5 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass | 2420ms |
| 6 | `rg -n "setup-node|playwright install chromium --with-deps|2375|playwright-report|verify_m006_s08_release" .github/workflows/ci.yml` | 0 | ✅ pass | 58ms |
| 7 | `dart run tool/verify_m006_s08_release.dart` | 1 | ❌ fail | 311000ms |

## Deviations

除计划内的 values / core templates 外，我额外更新了 `deploy/helm/babytalk/templates/NOTES.txt` 与 `deploy/helm/babytalk/templates/tests/test-connection.yaml`，因为这些辅助模板仍引用已移除的单 service 假设；不改它们会让 chart 内部说明和 Helm test 与新的 split topology 脱节。

## Known Issues

`dart run tool/verify_m006_s08_release.dart` 仍在 `admin-web/tests/knowledge-ops.spec.ts:299` 失败：`expect(tracker.events.length).toBe(afterFirstWindow)` expected `11` but received `13`。失败证据位于 `admin-web/playwright-report/index.html` 与 `admin-web/test-results/knowledge-ops-knowledge-op-a1125-hile-keeping-context-inline/`。

## Files Created/Modified

- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/values-production.yaml`
- `deploy/helm/babytalk/templates/_helpers.tpl`
- `deploy/helm/babytalk/templates/configmap.yaml`
- `deploy/helm/babytalk/templates/secret.yaml`
- `deploy/helm/babytalk/templates/deployment.yaml`
- `deploy/helm/babytalk/templates/service.yaml`
- `deploy/helm/babytalk/templates/ingress.yaml`
- `deploy/helm/babytalk/templates/NOTES.txt`
- `deploy/helm/babytalk/templates/tests/test-connection.yaml`
