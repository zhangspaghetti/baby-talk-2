---
phase: "35"
plan: "02"
---

# T02: Extracted Garden screen cards into dedicated shell widget files and restored clean Flutter verification.

**Extracted Garden screen cards into dedicated shell widget files and restored clean Flutter verification.**

## What Happened

按任务计划把 `garden_screen.dart` 中三组大体量私有显示组件拆到了 `features/shell/presentation/widgets/`：新增 `garden_hero_card.dart`、`garden_continue_card.dart`、`garden_patch_card.dart`，并把 `GardenScreen` 的 3 个调用点改为新公开组件，同时保留 `_GardenEmptyState` 与 `_GardenBanner` 在原文件内不动。抽取过程中保持了原有 widget body、keys、字符串、按钮行为与 continuity/growth 依赖不变，仅把私有类改名为公开类并补上 `super.key`。为解决验证门禁中的现有阻塞，我还清除了 `discover_space_section.dart` 末尾一次失败抽取留下的多余闭合片段，使 Discover 相关测试重新可编译。

## Verification

任务计划未提供额外 slice 级验证项，因此执行了计划中的 `flutter analyze` 与 `flutter test test/features/practice/garden_growth_shell_test.dart`；两者均通过。鉴于本轮门禁最初还被 Discover 抽取残留语法错误阻塞，我额外运行了 `flutter test test/features/shell/discover_screen_test.dart` 验证该阻塞已解除，结果也通过。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter analyze` | 0 | ✅ pass | 21500ms |
| 2 | `cd mobile && flutter test test/features/practice/garden_growth_shell_test.dart` | 0 | ✅ pass | 21500ms |
| 3 | `cd mobile && flutter test test/features/shell/discover_screen_test.dart` | 0 | ✅ pass | 9900ms |

## Deviations

除了计划中的 Garden 组件抽取外，我还删除了 `mobile/lib/features/shell/presentation/widgets/discover_space_section.dart` 末尾上轮残留的重复 `); } }` 语法尾巴；这是一次为恢复本任务验证所必需的最小修复，不涉及行为改动。

## Known Issues

None.

## Files Created/Modified

- `mobile/lib/features/shell/presentation/screens/garden_screen.dart`
- `mobile/lib/features/shell/presentation/widgets/garden_hero_card.dart`
- `mobile/lib/features/shell/presentation/widgets/garden_continue_card.dart`
- `mobile/lib/features/shell/presentation/widgets/garden_patch_card.dart`
- `mobile/lib/features/shell/presentation/widgets/discover_space_section.dart`
