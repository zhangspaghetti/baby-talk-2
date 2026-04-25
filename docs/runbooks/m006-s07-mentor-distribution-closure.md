# M006 / S07 Mentor Audit + Distribution Closure Runbook

## Reader and post-read action

**Reader:** 后续修改 admin shell、mentor audit、distribution stats 文案/诊断态的工程师或代理。

**读完后你应该能做的事：**

1. 判断一个需求属于 **S07 的组合语义对齐**，还是应该重开新 slice。
2. 从仓库根目录复跑 S07 closure proof，确认 mentor + distribution + shared shell 仍然一起保持 truthful。

## Why S07 exists

S07 是一个 **composition slice**，不是一次新的功能实现。

它只负责把已经落地的三个 truth surface 收口成一条可复跑、可解释的组合证明：

- **S04 / D101**：shared auth shell、route metadata、默认 landing、live `/api/admin/me` browser truth。
- **S10 / D099**：mentor audit 的 incident-first evidence、`deliveryState`、live rate-limit card，以及“不是完整 transcript”的边界。
- **S11 / D100**：distribution stats 的 release/share separation、release-only channel scope、detail redaction。
- **S07**：证明这些能力在同一个受保护 shell 中一起成立；如果 proof 暴露 wording / diagnostic drift，只做最小 copy 修正。

## Truth boundary

### Mentor audit

Mentor audit page 只展示 **`correlationId` 级别的 incident evidence**，不是完整 transcript。

可以 truthful 展示的内容：

- redacted request summary
- delivered response evidence（若存在）
- audit timeline
- 当前 installation 的 live rate-limit snapshot

不能在 S07 内补上的内容：

- 完整多轮 transcript
- raw prompt / raw provider payload
- 推断出来的 conversation history

如果产品要求“最近对话记录”升级为 **真正的 transcript/history browser**，要停止在 S07 里继续补文案，改为新 plan：这需要可信的 persisted conversation bridge，而不是 UI tweak。

### Distribution stats

Distribution stats page 的 `channel` **只作用于 release-side data**：

- `releaseOverview`
- `releaseTrend`
- `detailRows` 里的 release rows
- `shareHandoff` 的 release side

Raw share truth 仍然不带 channel：

- `shareOverview`
- `shareTrend`
- `shareFunnel`
- `detailRows` 里的 share rows

因此：

- 不能把 raw `share_landing_events` 说成被 `channel` 过滤
- 不能在 UI、日志或 proof 输出里泄漏 raw share token
- 如果未来要做 channel-scoped share analytics 或 rollup/backfill，也不属于 S07

### Shared shell and auth

组合证明里的 shell/auth truth 继续来自 **live `/api/admin/me`**。

必须保持显式可见的状态：

- stale-session redirect
- 403 route guard
- no-access landing / visible module resolution

S07 不重做 auth transport、RBAC hydration、或 route architecture。

## What may change in S07

**允许的改动：**

- route title / description
- page-level explanatory copy
- empty / error / normalized-query diagnostics
- closure runbook 与 proof tooling 文案

**不允许的改动：**

- 新 backend read model 或 endpoint
- transcript reconstruction
- 新 analytics rollup / charting 扩张
- 第二套 auth/session path

判断规则很简单：**如果不是组合 proof 暴露出来的 drift，就不要把它塞进 S07。**

## Canonical proof

首选的 repo-root closure replay：

```bash
dart run tool/verify_m006_s07_mentor_distribution.dart
```

这条命令会顺序执行并 fail fast：

```bash
./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest
npm --prefix admin-web run build
npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts mentor-distribution-closure.spec.ts
```

如果你只想定位某一层 drift，可以单独跑上面的 focused checks；如果要证明 **S07 已闭环**，以 `tool/verify_m006_s07_mentor_distribution.dart` 为准。

## How to interpret failures

- **UI 开始暗示 full transcript / recent conversation history**
  - 这是 D099 drift。先修 copy；如果需求真要 transcript，就新开 plan。
- **UI 或说明把 channel 说成覆盖全部 share data**
  - 这是 D100 drift。修正文案或 payload interpretation，不要补 fake analytics。
- **workspace title / subtitle 指到错误语义**
  - 这是 D101 route metadata drift。直接修 route metadata，不要重做导航架构。
- **看不到 live rate-limit card、share token 泄漏、403/stale-session 不再显式**
  - 这是 runtime regression，不是文档问题；必须让 proof 继续失败直到修复。

## Related runbooks

- [M006 / S10 Mentor Audit Incident Runbook](./m006-s10-mentor-audit.md)
- [M006 / S11 Distribution Stats Contract](./m006-s11-distribution-stats.md)
