---
phase: "06"
plan: "03"
---

# T03: feat: 动态练习前端集成 — DynamicPracticeApiService + ViewModel dynamic 模式 + TTS 按钮 + API 解析测试

**feat: 动态练习前端集成 — DynamicPracticeApiService + ViewModel dynamic 模式 + TTS 按钮 + API 解析测试**

## What Happened

将 T01 创建的后端 practice/generate API 完整集成到 Flutter 前端：

1. **DynamicPracticeApiService** — 新建 `mobile/lib/features/practice/data/services/dynamic_practice_api_service.dart`，包含 `DynamicPracticeResponse`/`DynamicActivity`/`DynamicPhrase` 数据类和 `generatePractice()` 方法。调用 `POST /api/v1/mentor/practice/generate`，处理网络/超时/格式异常，支持可选 sceneTag 和 conversationId。

2. **PracticeRepository.getActivitySnapshotDynamic()** — 新增方法调用 DynamicPracticeApiService，将 DynamicPhrase 映射为 PracticePhrase（audioAsset 设为空字符串标记 TTS 模式）。API 失败时 fallback 到 seed_content.json 首个 activity。添加了 `flutter/foundation.dart` 的 `debugPrint` 观测日志。

3. **PracticeSessionViewModel isDynamic 标志** — 构造函数新增 `isDynamic`、`babyAgeMonths`、`sceneTag` 参数。dynamic=true 时 `_loadHomeState()` 调用 `getActivitySnapshotDynamic()` 而非 `restorePracticeState()`。`ensureSessionReady()` 在 dynamic 模式复用已加载的 snapshot。`recordReaction()` 在 dynamic 模式跳过 Isar 事件写入（避免临时 ID 污染统计）。

4. **PhraseCard TTS 模式** — 新增 `isTtsMode` 和 `onTtsSpeak` 属性。dynamic 模式下 audioAsset 为空时显示 TTS 按钮（record_voice_over 图标）替代音频播放按钮。

5. **PracticeSessionScreen TTS 集成** — 在 `_PracticeSessionBodyState` 中创建 `FlutterTtsMentorAudioController` 实例（仅 dynamic 模式），连接到 PhraseCard 的 `onTtsSpeak` 回调，调用 `speakText(phrase.english)` 朗读。

6. **单元测试** — 8 个测试覆盖：合法 JSON 解析、空 activities、可选参数传递、非 JSON 响应异常、HTTP 500 异常、网络异常、缺失字段处理。全部通过。

## Verification

- `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings（仅 15 条 info 级预有问题）
- `flutter test test/features/practice/dynamic_practice_api_service_test.dart`: 8/8 tests passed
- `flutter test` 全套：77 passed, 31 failed — 所有失败均为 pre-existing（garden_growth_home_test、garden_growth_shell_test、practice_session_screen_test 中的 Null check in app_shell_screen.dart:35 / home_screen.dart:168），与本次改动无关
- `mvn compile test-compile -q`: exit 0，后端编译通过

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd mobile && flutter analyze --no-fatal-infos` | 0 | ✅ pass — 0 errors, 0 warnings | 14700ms |
| 2 | `cd mobile && flutter test test/features/practice/dynamic_practice_api_service_test.dart` | 0 | ✅ pass — 8/8 tests | 68000ms |
| 3 | `cd mobile && flutter test` | 1 | ⚠️ 77 passed, 31 failed — all failures pre-existing (garden_growth_*, practice_session_screen_test null check errors unrelated to T03) | 314200ms |
| 4 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 19500ms |

## Deviations

PhraseCard 新增 isTtsMode/onTtsSpeak 为可选参数，所有现有调用点保持不变无需修改。PracticeRepository 新增 dynamicPracticeApiService 为可选构造参数，不影响现有使用。

## Known Issues

31 个预存测试失败（garden_growth_home_test、garden_growth_shell_test、practice_session_screen_test）均为 app_shell_screen.dart:35 和 home_screen.dart:168 的 Null check 错误，与本次改动无关。

## Files Created/Modified

- `mobile/lib/features/practice/data/services/dynamic_practice_api_service.dart`
- `mobile/lib/features/practice/data/repositories/practice_repository.dart`
- `mobile/lib/features/practice/presentation/practice_session_view_model.dart`
- `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`
- `mobile/test/features/practice/dynamic_practice_api_service_test.dart`
