# M006 / S14 Release-Closure Handoff

## Status

M006 S14 verifier 与 child chain 仅保留为历史参考，不再是 CI 或仓库前门，当前不可运行。

当前仓库已进入 M007 Helm-first release boundary。`.github/workflows/ci.yml` 不调用 S14；CI 分别执行 backend tests、Checkstyle 与 Helm dual-chart smoke，并在最后聚合结果。

## Current CI-equivalent command

```bash
bash ci/k8s-smoke.sh
```

这是 README、CONTRIBUTING 与 CI 共同声明的唯一可执行 CI 前门。当前部署、回滚、`admin-api` internal-only 边界见 [Kubernetes split-stack deploy runbook](k8s-deploy.md)。

## Historical M006 reference (not runnable)

`tool/verify_m006_s14_release_closure.dart` 及其 S07、S08、S12、S13 child chain 只用于阅读历史 composition 结构。不要运行该 verifier 或任一 legacy child chain；S13/S12 仍依赖已归档或移除的 active 路径，执行结果不能作为当前 release proof。

## Historical child-gate map

| Stage | Verifier source | Runbook | Historical artifact |
| --- | --- | --- | --- |
| S07 mentor + distribution | `tool/verify_m006_s07_mentor_distribution.dart` | [S07 archived runbook](../archived/runbooks/m006-s07-mentor-distribution-closure.md) | `admin-web/playwright-report/index.html` |
| S08 Helm release | `tool/verify_m006_s08_release.dart` | [Kubernetes split-stack deploy runbook](k8s-deploy.md) | verifier stdout |
| S12 control-plane freshness | `tool/verify_m006_s12_control_plane_freshness.dart` | [S12 archived runbook](../archived/runbooks/m006-s12-control-plane-freshness.md) | `admin-web/playwright-report/index.html` |
| S13 repo front door | `tool/verify_m006_s13_demo_path.dart` | [S13 archived runbook](../archived/runbooks/m006-s13-demo-path.md) | verifier stdout |

归档 runbook 保留 M006 当时的诊断语境。不要把其中旧 front-door 文案重新提升为当前 release truth。

## Historical failure contract

S14 源码记录了当时的 fail-fast 设计：路径与 marker 必须存在，child non-zero、timeout 或缺 success marker 时停止。该设计说明仅供代码考古，不表示 legacy chain 当前可运行。

需要当前 release 证据时，只执行 `bash ci/k8s-smoke.sh`。不要按历史输出拼接 `drill_down_verifier`，也不要修补 archived chain 后宣称当前 CI 通过。

## CI handoff truth

当前 `.github/workflows/ci.yml` 顺序：

1. 启动 `localhost:2375` Docker relay。
2. `bash ci/backend-test.sh`。
3. Maven Checkstyle。
4. 停止 relay。
5. `bash ci/k8s-smoke.sh`。
6. 始终上传 `admin-web/playwright-report` 与 `admin-web/test-results`。
7. backend、Checkstyle、Helm 任一失败则最终 job 失败。

S14 不在该工作流内。M006 legacy verifier 的存在，不改变 `bash ci/k8s-smoke.sh` 是当前唯一可执行 CI 前门的事实。
