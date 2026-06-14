# BabyTalk Flutter Skill 审查汇总

日期：2026-05-28
状态：已完成
覆盖：4 个已使用 Skill + 6 个参考 Skill

---

## 1. flutter-architecting-apps（已使用）

### 审查结果：4 项改进

| # | 改进项 | 说明 |
|---|--------|------|
| 1 | Logic Layer | GardenFertilizerService、GrowthStatsService、PracticeRecommendationService |
| 2 | Service 边界 | ApiService 只做 HTTP，LocalStore 只做 Isar，Repository 做合并 |
| 3 | ViewModel 命名 | 统一使用 ChangeNotifier，ViewModel 作为 derived state |
| 4 | 测试策略 | 5 层测试金字塔（Service 90%/Repository 85%/ViewModel 80%/Widget 70%/E2E 100%） |

---

## 2. flutter-theming-apps（已使用）

### 审查结果：4 项改进

| # | 改进项 | 说明 |
|---|--------|------|
| 1 | Material 3 ColorScheme | 使用 ColorScheme.fromSeed() + Warm Paper Kindness 覆盖 |
| 2 | 组件主题规范化 | CardThemeData/AppBarThemeData/NavigationBarThemeData |
| 3 | 动画常量 | AppAnimationConstants（时长+缓动曲线） |
| 4 | 字体集成 | Fraunces/DM Sans/PingFang SC 集成到 ThemeData |

---

## 3. flutter-isar（已使用）

### 审查结果：6 项改进

| # | 改进项 | 说明 |
|---|--------|------|
| 1 | 新增 Collection | GardenEntity/FertilizerEntity/GrowthStatEntity/SettingsEntity |
| 2 | 安全存储 | flutter_secure_storage 存储 Token |
| 3 | SharedPreferences | 非敏感用户偏好 |
| 4 | 响应式查询 | watchLazy/watch 监听数据变化 |
| 5 | 离线同步队列 | Write-Behind 模式，SyncQueueEntity |
| 6 | 迁移策略 | 破坏性变更的迁移逻辑 |

---

## 4. flutter-managing-state（已使用）

### 审查结果：4 项改进

| # | 改进项 | 说明 |
|---|--------|------|
| 1 | 临时状态管理 | StatefulWidget + setState，不在 Notifier 中 |
| 2 | Provider 作用域 | 缩小到 feature 级别，避免全局污染 |
| 3 | 错误状态处理 | ErrorHandler mixin 统一错误映射 |
| 4 | 状态持久化策略 | 明确哪些状态需要持久化 |

---

## 5. flutter-setup-declarative-routing（参考）

### 路由配置建议

| 配置 | 方案 |
|------|------|
| 路由包 | go_router |
| Shell 路由 | StatefulShellRoute.indexedStack |
| 深层链接 | Path URL Strategy |
| 路由守卫 | redirect 处理登录状态 |
| 4 Tab | 首页/发现/花园/我 |

```dart
StatefulShellRoute.indexedStack(
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/')]),      // 首页
    StatefulShellBranch(routes: [GoRoute(path: '/discover')]), // 发现
    StatefulShellBranch(routes: [GoRoute(path: '/garden')]),  // 花园
    StatefulShellBranch(routes: [GoRoute(path: '/me')]),      // 我
  ],
)
```

---

## 6. flutter-setup-localization（参考）

### 国际化配置建议

| 配置 | 方案 |
|------|------|
| 包 | flutter_localizations + intl |
| 文件 | l10n.yaml + .arb 文件 |
| Phase 1 | 中文 UI + 英文内容 |
| Phase 2 | 英文 UI 可选 |
| 日期格式 | 中文习惯（X月X日） |

---

## 7. flutter-implement-json-serialization（参考）

### JSON 序列化建议

| 配置 | 方案 |
|------|------|
| 方案 | Freezed（类型安全+不可变+copyWith） |
| 大 JSON | compute() 在 Isolate 中解析 |
| API 模型 | 所有响应都有 fromJson/toJson |
| 测试 | 单元测试覆盖序列化/反序列化 |

---

## 8. flutter-build-responsive-layout（参考）

### 响应式布局建议

| 配置 | 方案 |
|------|------|
| 断点 | 320/360/430 宽度 |
| 布局 | LayoutBuilder 处理不同尺寸 |
| 安全区 | 底部导航 SafeArea 处理 |
| 小屏优先 | 320 宽度下优先保住核心内容 |

---

## 9. flutter-fix-layout-issues（参考）

### 布局问题修复建议

| 问题 | 修复 |
|------|------|
| 溢出 | 使用 Flexible/Expanded + Overflow |
| 对齐 | 使用 Align/Center + CrossAxisAlignment |
| 间距 | 使用 AppLayoutConstants 统一间距 |
| 安全区 | 使用 SafeArea + MediaQuery.of(context).viewPadding |

---

## 10. flutter-use-http-package（参考）

### HTTP 配置建议

| 配置 | 方案 |
|------|------|
| 包 | Dio（拦截器+Cookie 管理） |
| 错误处理 | 统一 DioException 拦截器 |
| 日志 | 调试模式下启用请求/响应日志 |
| 超时 | 连接 10s，接收 30s |
| 重试 | 网络错误自动重试 2 次 |

---

## 审查完成统计

| Skill | 状态 | 改进项 |
|-------|------|--------|
| flutter-architecting-apps | ✅ 已使用 | 4 项 |
| flutter-theming-apps | ✅ 已使用 | 4 项 |
| flutter-isar | ✅ 已使用 | 6 项 |
| flutter-managing-state | ✅ 已使用 | 4 项 |
| flutter-setup-declarative-routing | ✅ 参考 | 路由配置 |
| flutter-setup-localization | ✅ 参考 | 国际化配置 |
| flutter-implement-json-serialization | ✅ 参考 | JSON 序列化 |
| flutter-build-responsive-layout | ✅ 参考 | 响应式布局 |
| flutter-fix-layout-issues | ✅ 参考 | 布局修复 |
| flutter-use-http-package | ✅ 参考 | HTTP 配置 |

**总计：18 项改进 + 5 项参考配置**
