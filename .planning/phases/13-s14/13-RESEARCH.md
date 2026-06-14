# S14 Research — Playwright + CI + Helm release closure

## Summary

- 这个切片在当前 worktree 里已经有明显的实现骨架：`tool/verify_m006_s14_release_closure.dart` 已存在，`.github/workflows/ci.yml` 已把它设为 CI 顶层 gate，`README.md` / `CONTRIBUTING.md` / `docs/runbooks/m006-s14-release-closure.md` / `docs/runbooks/k8s-deploy.md` 也都把它当作唯一 repo-root release closure 入口。
- S14 的真实职责是 **evidence composition**，不是再发明一套新的 compose / Playwright / Helm 验证链。现有实现已经按这个边界组织：
  1. `S07` mentor + distribution closure
  2. `S08` Helm deploy truth（只走 `--helm`）
  3. `S12` Overview freshness full replay
  4. `S13` repo front-door truth
- 对本 slice 来说，最重要的是 **保持 child gate ownership 清晰**：S14 只组合，不重写；如果某个 proof 错了，应修 child verifier 本身，而不是在 S14 或 CI YAML 里复制一份逻辑。
- 从 planner 角度，这更像一个 **轻量/定向 research**：主要落点应在 `tool/`、`.github/workflows/`、root docs/runbooks、以及 root test harness，不需要再碰 admin feature 代码。

## Requirements in Scope

- **R052**：S14 自己不扩 Overview 边界；它通过复用 `tool/verify_m006_s12_control_plane_freshness.dart` 来保住 S12 已锁定的 truthful four-domain / fail-closed / last-good-snapshot contract。S14 若改成在 workflow 里直接拼局部 browser steps，会削弱这个 requirement 的单一真相源。
- **R053**：S14 继续推进“canonical repo-root closure path”。当前代码已经把 `tool/verify_m006_s14_release_closure.dart` 作为顶层入口、`.github/workflows/ci.yml` 作为同款 CI wiring、S13/S12 作为下钻入口；实现上应继续沿着这条单一路径收口，而不是让 README、CI、runbook 各自维护不同 release 命令链。

## Recommendation

- 按 **Karpathy Guidelines** 执行：
  - **Simplicity First**：S14 只做组合，不加新 harness，不把 child assertions 复制到 workflow shell 里。
  - **Surgical Changes**：如果要补强，优先补 `tool/verify_m006_s14_release_closure.dart` 的 contract test、CI wiring 的静态回归保护、以及对应 docs；不要顺手改 backend/admin-web。
  - **Goal-Driven Execution**：把成功标准收敛成“顶层 gate 可验证 + child gate 路由不漂移 + CI/artifact handoff 不漂移”。
- 现阶段最像“缺口”的不是功能实现，而是 **自动化防漂移测试不足**：
  - 目前没有 `test/tool/verify_m006_s14_release_closure_test.dart`。
  - child success marker / child order / S08 `--helm` 参数 / workflow 指向 S14 都主要靠人工读文件或实际跑 gate 才能发现 drift。
- 因此 planner 可以把 S14 当成：**已有主实现 + 需要最小硬化与最终验证**，而不是一个全新 feature slice。

## Implementation Landscape

### 1. Top-level release gate（已存在）

- `tool/verify_m006_s14_release_closure.dart`
  - fail-fast child gate runner。
  - 每个 child gate 都声明了：`gateId`、`stepLabel`、`verifierPath`、`verifierArgs`、`successMarker`、`timeout`、`runbookPath`、可选 `artifactHint`。
  - 明确 child 顺序是：`S07 -> S08(--helm) -> S12 -> S13`。
  - 如果 child `exit 0` 但没打出预期 `successMarker`，S14 会把它视为 malformed child output 并失败；这是 deliberate fail-closed contract，不是 accidental behavior。
  - 只支持 `--help`；没有其它 CLI 模式。

### 2. Child gates S14 依赖的真实 proof owner

- `tool/verify_m006_s07_mentor_distribution.dart`
  - 跑 `AdminMentorAuditWebTest,AdminDistributionStatsWebTest`
  - 跑 `npm --prefix admin-web run build`
  - 跑 Playwright proof pack：`access-and-landing.spec.ts`、`mentor-audit.spec.ts`、`distribution-stats.spec.ts`、`mentor-distribution-closure.spec.ts`
  - 这个 verifier 让 Playwright global setup 自己起 compose；S14 不应把它改成第二种 boot 模式。

- `tool/verify_m006_s08_release.dart`
  - 同时支持 `--runtime` / `--helm` / 默认 full gate。
  - S14 只消费 `--helm`，这和 memory 里的架构结论一致：deploy truth 继续由 S08 authoritative child 持有。
  - `ci/k8s-smoke.sh` 是 Helm truth surface，验证 named resources、hook、NOTES、internal-only `admin-api` 边界。

- `tool/verify_m006_s12_control_plane_freshness.dart`
  - full replay 路径：`backend_contract -> admin_web_build -> compose_boot -> runtime_truth -> browser_proof_pack`
  - 另有 `--live-stack-only` 给 S13 smoke 用。
  - `admin-web/playwright.global-setup.ts` 通过 `BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1` 支持 verifier-owned runtime reuse。

- `tool/verify_m006_s13_demo_path.dart`
  - 默认 `verify` 模式做静态 docs/link/wrapper parity proof。
  - `demo` / `smoke` 模式负责 repo-root demo wrappers 与 telemetry。
  - S14 当前走默认 `verify` 模式，这意味着它只吸收 front-door truth，不会重复 boot stack。

### 3. CI wiring（已存在）

- `.github/workflows/ci.yml`
  - job 名是 `release-closure-gate`。
  - 安装 JDK / Node / Dart / Playwright Chromium。
  - 起 `localhost:2375` Docker relay，并在 S14 step 上注入 `DOCKER_HOST=tcp://localhost:2375`。
  - 运行 `dart run tool/verify_m006_s14_release_closure.dart`。
  - `continue-on-error: true` 后用独立 failure step 终止 job，这样 `actions/upload-artifact` 还能在失败时保留 `admin-web/playwright-report` + `admin-web/test-results`。

### 4. Helm / deploy truth surfaces（已存在）

- `deploy/helm/babytalk/templates/deployment.yaml`
  - 三个明确 Deployment：`app-api`、`admin-api`、`admin-web`
  - 一个 `db-migration` pre-install/pre-upgrade hook Job
- `deploy/helm/babytalk/templates/service.yaml`
  - 三个明确 Service：`app-api`、`admin-api`、`admin-web`
- `deploy/helm/babytalk/templates/ingress.yaml`
  - 只会渲染 `app-api` 和 `admin-web` ingress
  - 没有 `admin-api` ingress；这是 internal-only 边界的核心来源
- `deploy/helm/babytalk/templates/NOTES.txt`
  - 对外入口只写 `app-api` / `admin-web`
  - `admin-api` 被明确标成 `svc/...:8081（仅集群内可达）`
- `deploy/helm/babytalk/templates/tests/test-connection.yaml`
  - helm test pod 会 probe `app-api`、`admin-api`、`admin-web`
- `deploy/helm/babytalk/values-production.yaml`
  - 生产值里 `appApi.ingress.enabled=true`、`adminWeb.ingress.enabled=true`
  - `adminApi` 没 ingress block，因此默认仍 internal-only

### 5. Docs / handoff surfaces（已存在）

- `docs/runbooks/m006-s14-release-closure.md`
  - 已描述 child-gate map、fail-fast semantics、CI handoff、drill-down 顺序
- `docs/runbooks/k8s-deploy.md`
  - 已把 S14 作为 repo-root release closure 命令；S08 保持 Helm authoritative child
- `README.md`
  - 已有 “Final release closure（CI 同款）” 段落，直接指向 `dart run tool/verify_m006_s14_release_closure.dart`
- `CONTRIBUTING.md`
  - verification ladder 已把 S14 放在 S13/S12 之后，且明确 front-door / docs / repo-root verifier 改动必须把 S14 加入 verification

### 6. Test harness pattern（存在，但 S14 还没接上）

- `pubspec.yaml`
  - root 已有 Flutter/Dart test harness
- `test/tool/verify_m006_s13_demo_path_test.dart`
  - 证明了 repo-root tool 可以通过 root test 做 CLI/config/telemetry contract 测试
- `mobile/test/tool/verify_m006_s13_demo_path_test.dart`
  - 只是对 root test 的 thin delegate
- **当前 repo 没有对应的 `test/tool/verify_m006_s14_release_closure_test.dart`**；这是 S14 最明显的可补强 seam

## Natural Seams

1. **Verifier contract seam** — `tool/verify_m006_s14_release_closure.dart`
   - child gate 顺序
   - child args（特别是 `S08` 必须保持 `--helm`）
   - success marker strings
   - runbook / artifact hint 映射
   - timeout budgets

2. **Workflow seam** — `.github/workflows/ci.yml`
   - 顶层 gate 是否仍指向 S14
   - Docker relay (`2375`) 是否仍保留
   - Playwright artifacts 是否仍 `if: always()` 上传
   - failure-after-upload 结构是否仍存在

3. **Docs seam** — `README.md`、`CONTRIBUTING.md`、`docs/runbooks/m006-s14-release-closure.md`、`docs/runbooks/k8s-deploy.md`
   - 是否仍只有一条 canonical repo-root release command
   - 是否仍正确下钻到 `S07/S08/S12/S13`
   - 是否重新 drift 回 ad-hoc YAML/shell 链

4. **Optional contract-test seam** — `test/tool/verify_m006_s14_release_closure_test.dart`
   - 低成本、无 compose/browser/runtime 依赖
   - 适合锁 child-gate order / args / docs/workflow expectations
   - 若需要可仿照 S13 增加 `mobile/test/tool/verify_m006_s14_release_closure_test.dart` thin delegate

## Risks / Constraints / Gotchas

- **Stringly-typed child success markers**：
  `tool/verify_m006_s14_release_closure.dart` 里把 child 成功条件写成硬编码字符串，例如：

  - `All M006/S07 mentor + distribution verification steps passed.`
  - `All M006/S08 release verification steps passed.`
  - `All M006/S12 overview control-plane verification steps passed.`
  - `All M006/S13 demo-path verification steps passed.`
  任何 child verifier 改 final success 文案但仍 exit 0，S14 都会 fail。这个行为是对的，但很脆弱，值得用测试守住。

- **S14 目前几乎没有自己的自动化测试**：
  代码、workflow、docs 都已经在，但防漂移主要靠手跑 gate 和手工 grep。对 planner 来说，这是最适合拆成小任务补强的地方。

- **Timeout budget 很紧，不适合再往 S14 加重步骤**：
  - S14 child timeout：`S07=30m`、`S08=10m`、`S12=25m`、`S13=10m`
  - CI 顶层 verifier step timeout：`45m`
  - S12 自己的 full replay 内部其实还包含 build/compose/browser 多段长步骤
  这意味着：**S14 不能再新增 runtime boot / extra browser pack / second helm proof**。如果 timeout 不稳，应先调预算或 child 结构，不要在 S14 里叠逻辑。

- **S07 / S12 / S13 的 compose ownership 不同，而且是刻意如此**：
  - `S07`：Playwright global setup own compose boot
  - `S12 full replay`：verifier own compose boot，再用 reuse flag 跑 browser pack
  - `S13 smoke`：调用 `S12 --live-stack-only`
  - `S14`：只是顺序调用 child，不应该抹平这些 ownership 差异

- **Helm truth 不能从 S08 漂移出来**：
  `admin-api` internal-only、db-migration hook、NOTES/public surface 边界都已经被 S08 + chart + `ci/k8s-smoke.sh` 收口；S14 只能 consume，不应重写说明或复制断言。

## What to Build / Prove First

1. **先补 S14 contract test（最小、最便宜）**
   - 目标不是跑 child gate，而是锁：child order、`S08 --helm`、runbook/artifact hints、以及顶层命令/CI handoff。
   - 如果现有 script 不好测，优先暴露一个最小 public getter/const 来承载 child gate metadata，而不是重构执行流。

2. **再按测试暴露的问题做最小修补**
   - `tool/verify_m006_s14_release_closure.dart`
   - `.github/workflows/ci.yml`
   - `README.md` / `CONTRIBUTING.md` / `docs/runbooks/m006-s14-release-closure.md` / `docs/runbooks/k8s-deploy.md`
   - 除非 child gate 真的坏了，否则不要去改 backend/admin-web business code

3. **最后用顶层 gate 做 closure proof**
   - S14 的“完成”不是局部 child rerun，而是 `dart run tool/verify_m006_s14_release_closure.dart` 真正通过

## Verification

### Cheap / static

```bash
dart run tool/verify_m006_s14_release_closure.dart --help
rg -n "verify_m006_s14_release_closure|playwright-report|upload-artifact|2375" .github/workflows/ci.yml
rg -n "verify_m006_s14_release_closure|verify_m006_s08_release|verify_m006_s07_mentor_distribution|verify_m006_s12_control_plane_freshness|verify_m006_s13_demo_path" README.md CONTRIBUTING.md docs/runbooks/m006-s14-release-closure.md docs/runbooks/k8s-deploy.md
```

### If adding S14 contract tests

```bash
flutter test test/tool/verify_m006_s14_release_closure_test.dart

# optional delegate parity if you mirror the S13 pattern

flutter test mobile/test/tool/verify_m006_s14_release_closure_test.dart
```

### Final closure

```bash
dart run tool/verify_m006_s14_release_closure.dart
```

## Skills Discovered

- 已有、且直接相关的 skills：
  - `github-workflows` — GitHub Actions / CI wiring review
  - `kubernetes-specialist` — Helm/Kubernetes deploy truth
  - `docker-expert` — compose/runtime boundary review
- 本 research 新安装：
  - `currents-dev/playwright-best-practices-skill@playwright-best-practices`
- 本次已显式启用：
  - `karpathy-guidelines` — 支持 “composition only / simplicity first / surgical changes / explicit verification” 的实现策略
