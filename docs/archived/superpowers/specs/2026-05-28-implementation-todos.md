# BabyTalk Flutter Mobile 实施 TODO

日期：2026-05-28
状态：待实施

---

## Phase 1：架构重构（Week 1-2）

### 1.1 统一 Riverpod

- [ ] 移除 `app/app.dart` 中的 legacy Provider 依赖
- [ ] 将所有 Notifier 迁移到 Riverpod ChangeNotifier
- [ ] 统一 Provider 定义在 `repository_providers.dart`
- [ ] 验证所有 Feature 的 Provider 作用域正确

### 1.2 缩小 Rebuild 范围

- [ ] 拆分 HomeScreen 的 root watch（home_screen.dart:174-176）
- [ ] 拆分 GardenGrowthCombinedScreen 的 root watch（67-74）
- [ ] 拆分 MentorPanelSheet 的 root watch（55-65）
- [ ] 使用 Selector 或较小的 watch 范围

### 1.3 添加 Logic Layer

- [ ] 创建 `garden/domain/services/garden_fertilizer_service.dart`
- [ ] 创建 `growth/domain/services/growth_stats_service.dart`
- [ ] 创建 `practice/domain/services/practice_recommendation_service.dart`
- [ ] 为每个 Service 编写单元测试

### 1.4 统一 Service 边界

- [ ] 确保 ApiService 只做 HTTP 调用
- [ ] 确保 LocalStore 只做 Isar 操作
- [ ] 确保 Repository 做数据合并和缓存
- [ ] 移除 Service 中的业务逻辑

---

## Phase 2：新增功能模块（Week 3-6）

### 2.1 Settings 模块

- [ ] 创建 `features/settings/data/local/settings_entity.dart`
- [ ] 创建 `features/settings/data/repositories/settings_repository.dart`
- [ ] 创建 `features/settings/presentation/settings_notifier.dart`
- [ ] 创建 `features/settings/presentation/screens/settings_screen.dart`
- [ ] 实现提醒设置子页面
- [ ] 实现宝宝档案子页面
- [ ] 实现照护者偏好子页面
- [ ] 实现播放偏好子页面
- [ ] 实现帮助与反馈子页面
- [ ] 实现关于子页面

### 2.2 Shell V2 更新

- [ ] 更新底部 Tab 名称："成长"→"我"
- [ ] 更新导航栏高度为 82px
- [ ] 创建"我"页面（头像+花园状态+成长数据+功能网格）
- [ ] 创建设置独立页面
- [ ] 更新 go_router 配置

### 2.3 Garden V2 模块

- [ ] 创建 `features/garden/data/local/garden_entity.dart`
- [ ] 创建 `features/garden/data/local/fertilizer_entity.dart`
- [ ] 创建 `features/garden/data/repositories/garden_repository.dart`
- [ ] 创建 `features/garden/domain/services/garden_fertilizer_service.dart`
- [ ] 创建 `features/garden/presentation/garden_notifier.dart`
- [ ] 实现单株花可视化（CSS/SVG 动画）
- [ ] 实现肥料领取交互
- [ ] 实现施肥交互
- [ ] 实现阶段变化庆祝动画
- [ ] 实现空态（种子状态）

### 2.4 Growth V2 模块

- [ ] 创建 `features/growth/data/local/growth_stat_entity.dart`
- [ ] 创建 `features/growth/data/repositories/growth_repository.dart`
- [ ] 创建 `features/growth/domain/services/growth_stats_service.dart`
- [ ] 创建 `features/growth/presentation/growth_notifier.dart`
- [ ] 实现 5 维度 tab（周/月/年/总/旅程）
- [ ] 实现柱状图组件
- [ ] 实现场景分布列表
- [ ] 实现里程碑时间线
- [ ] 实现花园状态联动

---

## Phase 3：更新现有功能（Week 7-10）

### 3.1 Onboarding V21

- [ ] 更新场景选择为纵向列表
- [ ] 去掉句卡边框
- [ ] 弱化发音按钮为小图标
- [ ] 添加小禾场景动态文案
- [ ] 宝宝反应改为图标+文字
- [ ] 自动跳转延长到 2.5-3s
- [ ] 实现种子萌芽动画
- [ ] 实现动态文案系统
- [ ] 添加触觉反馈
- [ ] 添加按钮缩放动画
- [ ] 添加页面转场动画

### 3.2 Home B

- [ ] 重构为照护时刻+小禾导师结构
- [ ] 实现照护时刻生成（时段+场景+动作）
- [ ] 实现小禾建议气泡（≤2 行）
- [ ] 实现快速救援纵向列表
- [ ] 实现临时场景流程
- [ ] 实现完成后变化（toast+CTA+花园摘要）

### 3.3 Discover

- [ ] 实现场景 pill 筛选
- [ ] 实现短语卡片+使用提示
- [ ] 实现排序功能（最常用/最新/全部）
- [ ] 实现搜索功能
- [ ] 实现场景详情页

### 3.4 Practice

- [ ] 去掉句卡边框
- [ ] 添加小禾场景动态文案
- [ ] 反应按钮改为图标+文字
- [ ] 自动跳转延长到 2.5-3s

### 3.5 Shell V2

- [ ] 更新底部 Tab："成长"→"我"
- [ ] 更新导航栏高度为 82px
- [ ] 创建"我"页面
- [ ] 创建设置独立页面
- [ ] 更新 go_router 配置

### 3.6 Auth V11

- [ ] 合并登录/注册流程
- [ ] 实现 OTP 自动填充
- [ ] 实现隐形验证码
- [ ] 更新品牌信任文案

---

## Phase 4：完善（Week 11-12）

### 4.1 测试

- [ ] 为所有新模块编写单元测试
- [ ] 为所有新模块编写 Widget 测试
- [ ] 编写关键路径集成测试
- [ ] 验证测试覆盖率

### 4.2 CI/CD

- [ ] 配置 GitHub Actions PR 验证流水线
- [ ] 配置 GitHub Actions 主分支构建流水线
- [ ] 配置 Firebase App Distribution 内测

### 4.3 监控

- [ ] 配置 Firebase Crashlytics
- [ ] 配置 Firebase Analytics
- [ ] 配置自定义事件追踪
- [ ] 配置性能监控

### 4.4 优化

- [ ] 优化应用启动时间
- [ ] 优化内存使用
- [ ] 优化包大小
- [ ] 验证 320/360/430 宽度适配
- [ ] 验证 TalkBack/VoiceOver

---

## 优先级排序

| 优先级 | 任务 | 阻塞 |
|--------|------|------|
| P0 | 架构重构（Phase 1） | 后续所有任务 |
| P0 | Settings + Shell V2 | 最简单的新增功能 |
| P1 | Garden V2 + Growth V2 | 核心增长功能 |
| P1 | Onboarding V21 + Practice 更新 | 核心体验功能 |
| P1 | Home B | 核心首页功能 |
| P1 | Auth V11 | 登录功能 |
| P2 | Discover | 内容浏览功能 |
| P2 | 测试 + CI/CD | 质量保障 |
| P2 | 监控 + 优化 | 性能保障 |
