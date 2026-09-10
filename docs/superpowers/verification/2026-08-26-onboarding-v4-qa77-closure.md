# Onboarding V4 / #77 QA 闭环证据

日期：2026-08-26（Asia/Shanghai）。本报告只记录自动化可复核结果；不把自动化语义、录音或系统状态写成真人听感/TalkBack 通过。

## 冻结候选

| 项目 | 值 |
| --- | --- |
| 部署 candidate ID | `m2-final-2ff3c79f3a11` |
| 后端镜像 | `babytalk/app-api:m2-final-2ff3c79f3a11`, `babytalk/admin-api:m2-final-2ff3c79f3a11`, `babytalk/admin-web:m2-final-2ff3c79f3a11`, `babytalk/gateway:m2-final-2ff3c79f3a11` |
| APK package/version | `com.babytalk.mobile` / `1.2.0` |
| APK SHA-256 | `abe020b0af644b1a5044d79e8c23e367f7cedad01491b80a70ae02bcedb32ada` |
| Required migration | `36` |
| Gateway | `http://127.0.0.1:19091`，`/qa/candidate-compatibility` = `compatible` |
| Manifest | `artifacts/qa/m2-final-2ff3c79f3a11/manifest.json`，SHA-256 `2df14c242d9d3ca84cd297b4ad19e4472f4e920390324f04b83688f4b03ebcd2` |
| Acceptance evidence | `artifacts/qa/m2-final-2ff3c79f3a11/evidence-final-pass-v4-rerun2.json`，SHA-256 `0820ceae82285a15531831ae51cce425b6fd4bc3ead867409576c7e9f4038c5d` |

部署快照（只读 `kubectl`）：四个 app Deployment Ready `1/1`；imageID 分别为 app-api `sha256:159831b5f9f645d7d46fa5e8e037bba9f4b2f366cf8a10e93f6b9e64a12e6975`、admin-api `sha256:a633cba344da6f382ba269957180f24f79024541b23052b5586f25de2c1adc3c`、admin-web `sha256:12f5471a1775eef695f0306179285c13ab9c1a0137c9833f01ce803a0d35cbba`、gateway `sha256:a919ad0670609d5d12d129ef0874ce0c8a13944536fa92cc538c5083a2928fef`。ConfigMap `babytalk-qa-app-shared-config` 同时声明 candidate `m2-final-2ff3c79f3a11` 与 migration `36`。

## V4 onboarding 自动验证

`flutter test integration_test/onboarding_v4_release_branches_test.dart -d emulator-5554 --reporter expanded --no-pub --no-uninstall`（同候选源码、显式 candidate/version defines）：`00:41 +4: All tests passed!`。

覆盖：

- online 首句、音频失败恢复、无反应路径、Continue 精确延续；
- offline 超时后 late HTTP 不替换本地 fallback；
- defer 持久化、显式 re-entry 恢复 checkpoint；
- Today 完成、Trace 发布、Garden handoff。

该测试会生成临时 integration APK；测试后用冻结备份恢复 release APK，并再次确认 SHA-256 为上表值。

移动快速层：

```text
flutter test test/features/care_entry test/features/care_path test/app/onboarding_v4_migration_test.dart test/smoke/app_boot_test.dart --concurrency=1 --no-pub
00:46 +123: All tests passed!
```

## #77 P0/P1、隐私、生命周期、安全

Candidate Acceptance Harness：`BTQA_CANDIDATE_ACCEPTANCE_V3`，最终 `PASS`，5/5：

| case | 结果 | 自动证据 |
| --- | --- | --- |
| `idempotent_account_sync` | PASS | first write/replay duplicate、bootstrap eventCount=1 |
| `two_account_household` | PASS | 两 synthetic account、invite accept/revoke、shared context isolation |
| `android_notification` | PASS | scheduler、posted notification、user-visible projection |
| `android_audio` | PASS | media session、controls、speed effect、user-visible projection |
| `android_deep_link` | PASS | cold/foreground intent、invalid fallback、recipient pre-acceptance boundary、join |

证据只保存 candidate/APK/device/version 与三类结果哈希；不保存原始 phone、token、验证码、invite token 或用户内容。

后端 targeted gate（`bash mvnw clean test -pl app-api -am`，指定 auth/consent/sync/invite/security/profile/purge/protector tests）：`Tests run: 58, Failures: 0, Errors: 0`，`BUILD SUCCESS`；Testcontainers 空库 Flyway 成功到 v36。另：QA runner 单测 `Ran 55 ... OK`，candidate identity CI 单测 `Ran 4 ... OK`；privacy/Spring AI/custom-scene gates 均 PASS。

## 修复提交

- `651ff5e8 fix(qa): retry Android UI readiness safely`：bounded UI dump retry、About identity 等待、profile trace 不再从 digest 产生 phone-like 11 位串；同步更新测试。
- `1edcf62a fix(mobile): align package version with API gate`：`mobile/pubspec.yaml` 从 `1.0.0+1` 对齐为 `1.2.0+1`，避免后端 `X-App-Version` 426。
- 基线候选修复：`2ff3c79f fix(qa): unblock Android candidate harness`。

QA worktree 中既有的 Windows generated plugin 文件与 `notif.txt` 未纳入提交。

## 问题可关闭性 / 唯一人工清单

自动化 P0/P1 与 V4 证据均通过，但 #76/#77 不能仅凭本 bundle 标记最终关闭。唯一剩余人工项：

1. 目标 release APK 上由真人确认远程/本地音频在目标设备可听、音量/倍速/暂停/恢复/重播体验符合预期；自动 media-session 证据不等于人耳证据。
2. 目标 release APK 开启真实 Android TalkBack，真人执行 touch exploration/手势，确认语义顺序、状态播报、返回焦点及音频共存；Flutter semantics 单测不替代 TalkBack。
3. 目标支持尺寸/字号上做人工视觉走查（onboarding、Continue/Today/Garden、通知/音频错误与恢复状态）。

完成以上三项并记录签名/设备/版本后，才具备 #76/#77 最终关闭条件。
