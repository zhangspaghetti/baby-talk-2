# Baby Talk 2 - Flutter 移动端全面重构计划

## Context

Baby Talk 2 的 Flutter 移动端当前使用 Provider + Navigator 1.0 + 手动序列化，UX 存在严重问题（信息过载、无动画、空状态无情感、加载状态不可见、可访问性缺失）。用户要求：
1. **技术栈迁移**: Riverpod + go_router + freezed + json_serializable + dio + flutter_hooks
2. **UI/UX 全面重设计**: 所有页面的人性化改进

**当前规模**: 9 个页面、30+ widget 文件、7 个 ChangeNotifier ViewModel、94 个 Dart 文件。

---

## 自动化测试策略

**原则**: 所有验证通过自动化测试完成，不依赖手动回归。

### 测试层次

| 层次 | 工具 | 覆盖范围 | 每 Phase 要求 |
|------|------|----------|---------------|
| 单元测试 | `flutter_test` | ViewModel、Repository、工具类 | 所有新/修改的 VM 和 Repository |
| Widget 测试 | `flutter_test` | 页面渲染、交互、状态变化 | 所有新/修改的 Screen 和 Widget |
| 集成测试 | `integration_test` | 端到端用户流程 | Phase 3/4 完成后运行 |
| Golden 测试 | `flutter_test` + golden | UI 视觉回归 | 关键页面的 light/dark 截图 |

### 测试目录结构

```
test/
├── unit/
│   ├── providers/          # Riverpod provider 测试 (Phase 3+)
│   ├── repositories/       # Repository 测试 (Phase 1+)
│   └── models/             # freezed model 测试 (Phase 1)
├── widget/
│   ├── screens/            # 页面级 widget 测试
│   └── widgets/            # 组件级 widget 测试
├── golden/
│   └── pages/              # Golden 截图回归
└── helpers/
    └── test_helpers.dart   # 共享测试工具 (mock providers, fake data)
integration_test/
├── onboarding_flow_test.dart
├── practice_flow_test.dart
├── shell_navigation_test.dart
└── account_flow_test.dart
```

### 测试工具准备

创建 `test/helpers/test_helpers.dart`:
```dart
// Riverpod 测试容器，预配置所有 overrides
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
}) => ProviderContainer(overrides: overrides);

// Mock 数据工厂
class TestData {
  static OnboardingSnapshot onboardingSnapshot() => ...;
  static GardenGrowthSnapshot gardenGrowthSnapshot() => ...;
  // ...
}
```

### 每个 Phase 的自动化验证清单

**Phase 0**: `flutter test` 全部通过 + widget 测试验证 AppBanner 渲染
**Phase 1**: `flutter test` + model 序列化/反序列化单元测试
**Phase 2**: `flutter test` + API service 单元测试 (mock Dio)
**Phase 3**: `flutter test` + 每个页面 widget 测试 + Riverpod provider 测试 + golden 测试
**Phase 4**: `flutter test` + 导航集成测试
**Phase 5**: `flutter test` + `flutter analyze` 零警告 + golden 回归

---

## Phase 0: 基础层 - 共享常量、Banner 提取、l10n 清理

**目标**: 消除重复代码和硬编码字符串，零运行时风险。

### Step 0.1: 创建布局常量

创建 `lib/app/theme/app_layout_constants.dart`:
- `maxContentWidth = 430` - 替换 10 个文件中的 `maxWidth: 430`
- `shellListPadding = EdgeInsets.fromLTRB(20, 12, 20, 120)`
- `screenListPadding = EdgeInsets.fromLTRB(20, 20, 20, 32)`

### Step 0.2: 提取共享 Banner widget

创建 `lib/app/widgets/app_banner.dart`，统一 8 个私有 Banner。支持可选 icon、action 按钮、可关闭。

### Step 0.3: 修复硬编码 fontSize: 28

替换为 `theme.textTheme.headlineMedium` (4 个文件)

### Step 0.4: 去重 `_resolvePhase`

提取为 `lib/features/account/presentation/account_surface_phase.dart`

### Step 0.5: l10n 迁移 (~50+ 硬编码中文)

grep 中文字符 -> 添加到 app_zh.arb -> flutter gen-l10n -> 替换引用

### Step 0.6: 标记废弃页面

garden_screen.dart, growth_screen.dart 添加 `@Deprecated`

### 验证
- `flutter analyze` + `flutter test` 通过
- Widget 测试: AppBanner 渲染正确、布局常量引用正确

---

## Phase 1: 数据模型 - freezed + json_serializable

**目标**: 代码生成替换手动序列化。仅触碰 domain/data 层。

### Step 1.1: 添加依赖 (freezed_annotation, json_annotation, freezed, json_serializable)

### Step 1.2: 迁移领域模型（叶子优先）

叶子: account_session, household_invite_link, local_mentor_suggestion, mentor_fact_event, interaction_event_payload, practice_phrase, share_link_draft

复合: onboarding_snapshot(保留 fromJsonValidated), practice_continuity_snapshot, practice_activity_catalog, garden_growth_snapshot

### Step 1.3: 更新仓库序列化调用 (toJsonMap->toJson, fromJsonMap->fromJson)

### Step 1.4: Isar 实体保持不变

### Step 1.5: `dart run build_runner build --delete-conflicting-outputs`

### 验证 (自动化)
- `dart run build_runner build` 成功
- **单元测试**: 每个 freezed model 的序列化/反序列化往返测试
- **关键测试**: `test/unit/models/onboarding_snapshot_test.dart` — 验证 fromJsonValidated 与旧 fromJsonMap 输出一致
- `flutter test` 全部通过

---

## Phase 2: 网络层 - dio（可与 Phase 1 并行）

### Step 2.1: 添加 `dio: ^5.7.0`，移除 `http`

### Step 2.2: 创建 `lib/core/network/app_dio.dart`

### Step 2.3: 迁移 6 个 API 服务类，AuthenticatedApiClient 变为 Dio Interceptor

### Step 2.4: `validateStatus: (status) => true` 过渡

### 验证 (自动化)
- **单元测试**: 每个 API service 的请求/响应测试 (mock Dio)
- **单元测试**: AuthInterceptor 正确注入 Authorization header
- `flutter test` 全部通过

---

## Phase 3: UI/UX 重设计 + Riverpod 迁移（合并，最高优先级）

**目标**: 每个页面同时完成 UI/UX 改进和 Riverpod 迁移。先构建共享 UI 组件，再逐页重写。

### Step 3.1: 添加依赖

```yaml
flutter_riverpod: ^2.6.1
riverpod_annotation: ^2.6.1
hooks_riverpod: ^2.6.1
flutter_hooks: ^0.21.2
# dev: riverpod_generator: ^2.6.3
# 移除 provider
```

### Step 3.2: 构建共享 UI 组件库

创建 `lib/app/widgets/` 目录：

- **AppShimmer** - 骨架屏 shimmer 动画，替换 4px 灰色条
- **AppEmptyState** - 插图 + 标题 + 描述 + CTA，支持不同主题
- **AppBanner** (升级) - 增加可关闭、层级 severity、自动消失
- **AppStepProgress** - 步骤进度条，用于 onboarding
- **AppCelebrationOverlay** - 完成练习/onboarding 的庆祝效果
- **AppHaptics** - 触觉反馈工具类
- **AppPageTransition** - 统一页面过渡动画 (fade+slide, 200ms)

### Step 3.3: Riverpod 基础设施

- ProviderScope 包裹 app，与 MultiProvider 共存
- 仓库迁移到 Riverpod providers
- ViewModel 迁移顺序: GardenGrowth -> Share -> Continuity -> Household -> Onboarding -> Account -> Mentor

### Step 3.4: 逐页面重设计 + 迁移

---

#### 3.4.1 OnboardingScreen 重设计

**当前问题**: 无进度指示、聊天比喻不一致、欢迎步骤多余、输入无实时验证、年龄卡片太小、完成无庆祝

**改进**:
- AppStepProgress 顶部进度条 (4 步)
- 合并欢迎步骤到名称步骤（信息横幅+输入框同屏）
- 名称输入实时验证（输入时显示绿色勾/红色提示）
- 年龄网格从 4 列改 3 列，触摸目标 44px+
- 选择卡片 AnimatedContainer 缩放 + AppHaptics.lightTap()
- 提交成功 AppCelebrationOverlay (2 秒) 再导航
- HookConsumerWidget + useTextEditingController()

**文件**: onboarding_screen.dart(重写), quick_select_card.dart(动画), mentor_bubble.dart(保持)

---

#### 3.4.2 AppShellScreen 重设计

**当前问题**: 抽屉触发器不明确、抽屉内容过载、开发笔记可见、Discover 隐藏、无标签切换动画

**改进**:
- 底部导航 3 个标签: 练习 / 发现 / 成长
- DiscoverScreen 从 modal 变为正式第三个 tab
- 抽屉触发器改为标准 hamburger 图标
- 抽屉精简: 头像+名字+阶段+快捷操作
- 移除开发笔记
- IndexedStack 3 个子页面 + AnimatedSwitcher 过渡
- FAB 滚动时自动隐藏/显示

**文件**: app_shell_screen.dart(重写), discover_screen.dart(从 modal 改 tab 内嵌)

---

#### 3.4.3 HomeScreen 重设计

**当前问题**: 信息过载 (12+ 卡片)、banner 堆叠不可关闭、加载状态不可见、无下拉刷新

**改进**:
- 信息分层: 核心区(TodaySceneCard+PersonalizedHero) + 折叠详情区
- Banner 可关闭，最多同时 1 个 (error>warning>info)
- 加载改 AppShimmer 骨架屏
- 添加 RefreshIndicator
- FAB 滚动隐藏/显示
- 移除 kDebugMode 调试文本
- Guest 模式引导改进
- ConsumerStatefulWidget + hooks

**文件**: home_screen.dart(重写), 6 个 home_* widget 文件

---

#### 3.4.4 PracticeSessionScreen 重设计

**当前问题**: 所有句子同时显示、调试标签泄露、状态英文、完成无庆祝、播放按钮缺反馈

**改进**:
- 单句聚焦模式: 只显示当前句子，已完成折叠为进度圆点
- 移除调试标签
- 状态标签本地化
- 完成时 AppCelebrationOverlay + 练习摘要
- 播放按钮增大 88x88 + AnimatedScale + 波纹动画
- 播放中音频波形动画
- 反应区域添加引导文字
- ConsumerStatefulWidget + hooks

**文件**: practice_session_screen.dart(重写), activation_frame.dart, phrase_card.dart, reaction_chip_row.dart

---

#### 3.4.5 GardenGrowthCombinedScreen 重设计

**当前问题**: 花园/成长无分隔、空状态纯文本、日记/里程碑截断无扩展

**改进**:
- Segmented Control: 花园/成长，左右滑动切换
- AppEmptyState 带插图
- 日记/里程碑添加"查看全部"
- AppShimmer 骨架屏
- l10n 修正
- ConsumerWidget

**文件**: garden_growth_combined_screen.dart(重写), garden_hero_card.dart, garden_continue_card.dart, garden_patch_card.dart

---

#### 3.4.6 DiscoverScreen 重设计

**当前问题**: modal 不合理、加载不可见、错误暴露技术细节、无搜索/筛选

**改进**:
- 变为 shell 第三个 tab
- 添加搜索栏
- 活动卡片图标/颜色编码
- 视图切换说明内联
- 移除装饰 hero card
- 错误信息用户友好化
- AppShimmer

**文件**: discover_screen.dart(重写), discover_activity_card.dart, discover_space_section.dart, discover_view_toggle.dart

---

#### 3.4.7 AccountEntryScreen 重设计

**当前问题**: 777 行、51+ 硬编码、_resolvePhase 重复、测试数据可见

**改进**:
- 拆分: account_status_card.dart, account_entry_screen.dart, account_phase_helpers.dart
- 全部迁移到 ARB
- 测试数据 kDebugMode only
- phase 描述精简
- 状态卡片添加图标
- HookConsumerWidget

**文件**: account_entry_screen.dart(拆分+重写)

---

### Step 3.5: app.dart 根组件重构 (~961 -> ~300-400 行)

### Step 3.6: 移除 Provider 依赖

### 验证 (自动化，每个 VM 迁移后)

**Riverpod Provider 测试** (每个 Notifier):
```dart
testWidgets('GardenGrowthNotifier initializes correctly', (tester) async {
  final container = createTestContainer(overrides: [...]);
  final notifier = container.read(gardenGrowthNotifierProvider.notifier);
  await notifier.initialize();
  expect(container.read(gardenGrowthNotifierProvider).status, GardenGrowthLoadStatus.loaded);
});
```

**Widget 测试** (每个重设计的页面):
```dart
testWidgets('HomeScreen shows shimmer while loading', (tester) async {
  await tester.pumpWidget(createTestApp(overrides: [continuityProvider.overrideWith(...)]));
  expect(find.byType(AppShimmer), findsOneWidget);
});

testWidgets('HomeScreen shows personalized hero when loaded', (tester) async {
  await tester.pumpWidget(createTestApp(overrides: [...]));
  await tester.pump();
  expect(find.byType(HomePersonalizedHero), findsOneWidget);
});

testWidgets('PracticeSessionScreen shows one phrase at a time', (tester) async {
  await tester.pumpWidget(createTestApp(...));
  expect(find.byType(ActivationFrame), findsOneWidget);
  // 其他句子不显示 ActivationFrame
});
```

**Golden 测试** (关键页面 light+dark):
```dart
testWidgets('HomeScreen golden - light mode', (tester) async {
  await tester.pumpWidget(createTestApp(theme: ThemeMode.light));
  await expectLater(find.byType(HomeScreen), matchesGoldenFile('golden/pages/home_light.png'));
});
```

**集成测试** (Phase 3 完成后):
- `integration_test/onboarding_flow_test.dart` — 完成 onboarding 到进入首页
- `integration_test/practice_flow_test.dart` — 从首页进入练习、完成一句
- `integration_test/shell_navigation_test.dart` — 三个 tab 切换
- `integration_test/account_flow_test.dart` — 账号状态显示

**可访问性测试**:
```dart
testWidgets('all interactive elements have semantics', (tester) async {
  await tester.pumpWidget(createTestApp());
  // 遍历所有按钮/卡片，验证 Semantics 存在
});
```

---

## Phase 4: 路由 - Navigator 1.0 -> go_router

### Step 4.1: 添加 `go_router: ^14.8.1`

### Step 4.2: 创建 `lib/app/router/app_go_router.dart`

路由: `/`(shell), `/onboarding`, `/practice`, `/account`
Shell 使用 StatefulShellRoute 保持底部导航状态

### Step 4.3: 迁移导航调用

### Step 4.4: 处理 reentry 协调器

### Step 4.5: 移除旧路由

### 验证 (自动化)
- **集成测试**: `integration_test/shell_navigation_test.dart` — 3 个 tab 切换、返回按钮
- **集成测试**: `integration_test/onboarding_flow_test.dart` — onboarding 完成后自动跳转
- **单元测试**: GoRouter redirect 逻辑测试 (未完成 onboarding 时重定向)
- **单元测试**: reentry coordinator 导航调用测试

---

## Phase 5: Hooks + 最终清理

### Step 5.1: flutter_hooks 统一应用到所有 controller 生命周期

### Step 5.2: 可访问性补全 (Semantics, 对比度, 触摸目标)

### Step 5.3: `dart format .` + `dart analyze --fatal-infos`

### Step 5.4: 更新项目文档

### 验证 (自动化)
- `flutter analyze --fatal-infos` 零警告
- `flutter test` 全部通过 (单元 + widget + golden)
- `dart format --set-exit-if-changed .` 通过
- Golden 回归: 所有 golden 页面截图匹配

---

## 依赖关系

```
Phase 0 --> Phase 1 --> Phase 3 (UI/UX + Riverpod) --> Phase 4 (go_router) --> Phase 5
                \--> Phase 2 (dio) --/
```

## 预估工作量

| Phase | 工作量 | 风险 | 说明 |
|-------|--------|------|------|
| Phase 0 | 2-3 天 | 低 | 纯提取 |
| Phase 1 | 3-4 天 | 低-中 | 序列化兼容性 |
| Phase 2 | 1-2 天 | 低 | http->dio |
| Phase 3 | 8-12 天 | 高 | UI/UX + Riverpod 合并 |
| Phase 4 | 2-3 天 | 中 | 路由 |
| Phase 5 | 1-2 天 | 低 | Hooks + 清理 |
| **总计** | **17-26 天** | | |

## UX 改进核心指标

| 指标 | 当前 | 目标 |
|------|------|------|
| 页面过渡动画 | 0 处 | 所有页面切换 |
| 微交互 | 0 处 | 所有按钮/卡片 |
| 空状态插图 | 0 处 | 所有空状态 |
| 骨架屏加载 | 0 处 | 所有列表/卡片 |
| 触觉反馈 | 0 处 | 关键操作 |
| Semantics 标签 | 5 处 | 所有交互元素 |
| 可关闭 Banner | 0 处 | 所有 Banner |
| 底部导航标签 | 2 个 | 3 个 |

## 关键文件

- `lib/app/app.dart` (961 行) - 根组件
- `lib/features/account/presentation/screens/account_entry_screen.dart` (777 行)
- `lib/features/practice/presentation/screens/home_screen.dart` (689 行)
- `lib/features/practice/presentation/screens/practice_session_screen.dart` (386 行)
- `lib/features/shell/presentation/app_shell_screen.dart` (428 行)
- `lib/features/shell/presentation/screens/discover_screen.dart` (433 行)
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` (746 行)
- `lib/features/shell/presentation/screens/garden_growth_combined_screen.dart` (430 行)
- `lib/app/theme/app_theme.dart` (743 行) - 保留
