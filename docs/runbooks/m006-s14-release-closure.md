# M006 / S14 Release-Closure Runbook

## Reader and outcome

**Reader:** 需要在本地或 CI 中判断“这次 M006 admin 闭环是否真的 ready for release”的工程师 / 代理。

**读完后你应该能做的事：**

1. 在 repo root 运行唯一的顶层 closure gate。
2. 从第一个失败的 child gate 直接下钻到对应 verifier / runbook / artifact。
3. 理解 S14 只做 evidence composition，不重建第二套 compose / browser / Helm harness。

## Boundary

S14 不是新的部署系统，也不是新的 browser harness。

它只负责把已经存在的 proof surfaces 串成一条 **release-closure chain**：

1. **S07** — mentor audit + distribution closure truth
2. **S08** — Helm split-stack deploy truth（在 S14 中保持 `--helm` authoritative）
3. **S12** — Overview freshness + SSE→polling fallback truth
4. **S13** — repo-root demo/front-door truth

S14 **不**负责：

- 再写一套 compose health / Playwright / Helm 验证逻辑
- 把 `admin-api` 变成 public surface
- 复制 child gate 的业务断言到 YAML 或 shell wrapper 里

## Canonical command

```bash
dart run tool/verify_m006_s14_release_closure.dart
```

仓库根唯一 final release command 始终是这条 S14 gate。

这条命令会 **fail fast**：

- 一旦某个 child gate 失败，S14 立刻停止
- 输出失败的 step label
- 输出可重跑的 child verifier 命令
- 输出 drill-down runbook
- 如适用，指出 `admin-web/playwright-report/index.html` 这类 artifact 路径

## Child-gate map

| Stage label | Child verifier | Proof owned by child | Drill-down |
| --- | --- | --- | --- |
| `Release closure | S07 mentor + distribution gate` | `dart run tool/verify_m006_s07_mentor_distribution.dart` | mentor audit / distribution closure、focused backend contracts、browser closure proof | [S07 runbook](m006-s07-mentor-distribution-closure.md) |
| `Release closure | S08 Helm release gate` | `dart run tool/verify_m006_s08_release.dart --helm` | Helm lint / template / hook / NOTES truth；`admin-api` internal-only 边界 | [Kubernetes split-stack deploy runbook](k8s-deploy.md) |
| `Release closure | S12 control-plane freshness gate` | `dart run tool/verify_m006_s12_control_plane_freshness.dart` | Overview summary / stream contract、polling fallback、transport diagnostics | [S12 runbook](m006-s12-control-plane-freshness.md) |
| `Release closure | S13 repo front-door gate` | `dart run tool/verify_m006_s13_demo_path.dart` | README / CONTRIBUTING / wrappers / Windows parity / next-action semantics | [S13 runbook](m006-s13-demo-path.md) |

## Why S08 stays authoritative for deploy truth

S08 已经把 split-stack deploy 真相收口到 Helm smoke：

- `db-migration` 是唯一 schema owner
- `app-api` / `admin-web` 是 public surface
- `admin-api` 是 **internal-only**
- NOTES / rendered resources / hook order 由 `ci/k8s-smoke.sh` 证明

因此 S14 不再重写一版“最终发布逻辑”；它只把 **S08 Helm truth** 纳入最终 closure chain。

## CI handoff

`.github/workflows/ci.yml` 现在应该直接调用：

```bash
dart run tool/verify_m006_s14_release_closure.dart
```

CI wiring 的关键点：

1. 继续保留 `localhost:2375` Docker relay，满足 backend Testcontainers 的 Windows parity 假设。
2. 顶层 gate 改成 S14，而不是继续把 S08 当最终 repo-root closure。
3. `actions/upload-artifact` 继续在 `if: always()` 下上传：
   - `admin-web/playwright-report`
   - `admin-web/test-results`
4. 即使顶层 gate 失败，也要保留 child gate 已生成的 drill-down artifacts。

## Failure semantics

### Child verifier missing

- 这是 **hard failure**，不是“跳过这个子项”
- S14 会直接失败，并指出缺失的 verifier 路径

### Child verifier timeout

- S14 会输出超时的 child gate label
- 不继续跑后续 child gate
- 由对应 child verifier / runbook 接手排障

### Child verifier exits non-zero

- S14 立刻停止在第一个 red gate
- 不继续跑后面的 S12 / S13 / Helm / docs gate
- 失败信息里必须带可重跑命令与 runbook 路径

### Child output malformed

如果 child process `exit 0`，但缺少预期 success marker，S14 会把它视为 **malformed child output** 并失败；这能防止“子脚本 silently changed but aggregator still goes green”。

## How to debug by failing stage

### `Release closure | S07 mentor + distribution gate`

优先看：

- `dart run tool/verify_m006_s07_mentor_distribution.dart`
- [S07 runbook](m006-s07-mentor-distribution-closure.md)
- `admin-web/playwright-report/index.html`

### `Release closure | S08 Helm release gate`

优先看：

- `dart run tool/verify_m006_s08_release.dart --helm`
- `bash ci/k8s-smoke.sh`
- [Kubernetes split-stack deploy runbook](k8s-deploy.md)

### `Release closure | S12 control-plane freshness gate`

优先看：

- `dart run tool/verify_m006_s12_control_plane_freshness.dart`
- [S12 runbook](m006-s12-control-plane-freshness.md)
- `admin-web/playwright-report/index.html`

### `Release closure | S13 repo front-door gate`

优先看：

- `dart run tool/verify_m006_s13_demo_path.dart`
- [S13 runbook](m006-s13-demo-path.md)
- README / CONTRIBUTING / wrapper parity / relative links

## Front-door traceability

从 fresh reader 角度，release closure 的阅读顺序应该是：

1. `README.md` —— 先看到 repo-root front door 与最终 release-closure 命令
2. 本 runbook —— 理解 S14 如何把 milestone promise 串到 child evidence
3. child verifier / child runbook —— 看具体 proof surface
4. CI artifact —— 看 Playwright HTML report / `test-results` / failing log

## Sensitive output rules

S14 及其引用的 docs / CI handoff 都不应该打印：

- JWT / refresh token
- bootstrap password
- raw mentor/share payload
- public `admin-api` URL

`admin-api` 在 deploy truth 与文档里都只能保持 **internal-only** 叙事。

## Canonical verification

```bash
dart run tool/verify_m006_s14_release_closure.dart
rg -n "verify_m006_s14_release_closure|playwright-report|upload-artifact|2375" .github/workflows/ci.yml
rg -n "verify_m006_s14_release_closure|verify_m006_s08_release|verify_m006_s07_mentor_distribution|verify_m006_s12_control_plane_freshness|verify_m006_s13_demo_path" docs/runbooks/m006-s14-release-closure.md README.md CONTRIBUTING.md docs/runbooks/k8s-deploy.md
```
