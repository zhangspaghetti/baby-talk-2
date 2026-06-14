---
phase: "12"
plan: "02"
---

# T02: Aligned front-door docs and telemetry guidance, but full demo-path closure remains blocked by S12 overview fallback instability.

**Aligned front-door docs and telemetry guidance, but full demo-path closure remains blocked by S12 overview fallback instability.**

## What Happened

我先完成了 T02 原始范围内的 front-door closure：更新 `README.md`、`CONTRIBUTING.md`、`mobile/README.md` 和 `docs/runbooks/m006-s13-demo-path.md`，把 repo-root admin demo 的唯一入口、thin smoke 复用 live stack 的语义，以及 bounded redaction-safe telemetry history `tmp/m006-s13-front-door-metrics.jsonl` 讲成同一个 fresh-reader 故事。随后我收紧了 `tool/verify_m006_s13_demo_path.dart` 的静态 contract，把 telemetry path / hotspot markers 也纳入 docs truth 校验，并在 `test/tool/verify_m006_s13_demo_path_test.dart` 固定了 repo-root telemetry history path。四个 wrappers 经核对后保持极薄委托设计，没有做额外 shell-specific 改写。

在真实 parity rerun 里，Windows smoke 先暴露了 `overview-control-plane.spec.ts` 的 malformed-summary refresh race：手动 refresh 命中的 malformed payload 会被后台成功 refresh 很快清掉，导致 `overview-summary-error` 不稳定。我在 `admin-web/src/pages/OverviewPage.tsx` 里让手动 refresh 错误不再被后台 poll 立即清除，并让进入 polling fallback 时关闭旧 stream。继续 rerun 后，POSIX smoke 又暴露了第二个 race：即使已经 fallback，Overview 仍可能被旧 stream 回调抬回 `recovered`。我继续在同一页面里加入 superseded stream callback 的 generation invalidation 护栏。

到硬超时恢复触发时，front-door docs/verifier 收口已经完成，Windows demo / smoke 也曾在第一轮 S12 修正后通过；但最新 POSIX smoke 仍失败在 offline fallback proof，因此没法诚实地宣称 T02 fully closed。当前最有价值的 durable state 是：repo-root docs 和 static verifier 已对齐，真实阻塞点已收敛到 S12 Overview fallback state machine，而不是 README / wrapper drift。

## Verification

- ✅ `flutter test test/tool/verify_m006_s13_demo_path_test.dart` 通过，repo-root telemetry path contract 与 reducer 逻辑仍然成立。
- ✅ `dart run tool/verify_m006_s13_demo_path.dart` 通过，README / CONTRIBUTING / mobile README / S13 runbook / wrapper parity 的静态 contract 对齐完成。
- ✅ `powershell.exe -NoProfile -Command "& '.\\scripts\\dev-up-admin-demo.cmd'"` 与 `powershell.exe -NoProfile -Command "& '.\\scripts\\dev-verify-admin-demo.cmd'"` 在第一次 S12 修正后都通过，说明 malformed-summary refresh race 已从 Windows smoke 视角收敛。
- ✅ 最新 `./scripts/dev-up-admin-demo.sh` 通过，POSIX demo 仍能在 `<2 min` 内带起 split stack，并输出统一 telemetry handoff。
- ❌ 最新 `./scripts/dev-verify-admin-demo.sh` 仍失败于 `fast_smoke`：`overview-control-plane.spec.ts` 的 offline fallback proof 没能稳定保持 `overview-polling-alert` / `transport: polling`。
- ⏭️ 因为最后一个 blocker 发生在最新 POSIX smoke，且硬超时恢复要求立即落盘，我没有在最后一轮 `OverviewPage.tsx` stream-generation guard 之后重新跑 Windows wrappers 或最终 `node -e <telemetry closure>`。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `npm --prefix admin-web run typecheck` | 0 | ✅ pass | 5768ms |
| 2 | `flutter test test/tool/verify_m006_s13_demo_path_test.dart` | 0 | ✅ pass | 8006ms |
| 3 | `dart run tool/verify_m006_s13_demo_path.dart` | 0 | ✅ pass | 4563ms |
| 4 | `powershell.exe -NoProfile -Command "& '.\\scripts\\dev-up-admin-demo.cmd'"` | 0 | ✅ pass | 81872ms |
| 5 | `powershell.exe -NoProfile -Command "& '.\\scripts\\dev-verify-admin-demo.cmd'"` | 0 | ✅ pass | 25046ms |
| 6 | `./scripts/dev-up-admin-demo.sh` | 0 | ✅ pass | 79725ms |
| 7 | `./scripts/dev-verify-admin-demo.sh` | 1 | ❌ fail | 29800ms |

## Deviations

为了追查 parity rerun 暴露的 S12 flaky behavior，额外修改了 `admin-web/src/pages/OverviewPage.tsx`：一是让手动 summary refresh 的 `invalid_response_payload` 不会被后台成功 refresh 立刻吞掉；二是开始在 polling fallback 时关闭并失效化 superseded stream callbacks。该文件不在原始 T02 输入列表里，但这是定位 `fast_smoke` 真正阻塞点所必需的最小改动。

## Known Issues

`./scripts/dev-verify-admin-demo.sh` 的最新 rerun 仍然在 `fast_smoke` 阶段失败。失败点是 `admin-web/tests/overview-control-plane.spec.ts` 的 offline fallback proof：页面会出现 `polling 未成功更新快照 (network_error)`，但 `overview-polling-alert` / `transport: polling` 仍未稳定出现，说明 S12 Overview realtime→polling→recovery 状态机还有剩余 race。由于硬超时恢复要求立即落盘，我没有在最后一次 `OverviewPage.tsx` stream-generation guard 之后重新跑 Windows `.cmd` wrappers 或 telemetry node closure。

## Files Created/Modified

- `README.md`
- `CONTRIBUTING.md`
- `mobile/README.md`
- `docs/runbooks/m006-s13-demo-path.md`
- `tool/verify_m006_s13_demo_path.dart`
- `test/tool/verify_m006_s13_demo_path_test.dart`
- `admin-web/src/pages/OverviewPage.tsx`
