# Superpowers 文档索引

本目录保存由 Superpowers / gstack 工作流沉淀的设计规格和实施计划。规格文件记录已经确认的产品与交互结论；计划文件记录可执行的工程步骤。

---

## 实施计划

| 文件 | 说明 |
|------|------|
| [未提交审查与分批提交实施计划](plans/2026-05-30-uncommitted-review-and-staged-commit-implementation-plan.md) | Task1 代码质量问题修复与分步提交方案 |

---

## Flutter Mobile 设计规格

### 页面设计

| 文件 | 页面 | 版本 |
|------|------|------|
| [Onboarding V21](specs/2026-05-28-flutter-mobile-onboarding-v21-design.md) | 引导页 | V21（场景优先+萌芽动画） |
| [Onboarding V20](specs/2026-05-26-flutter-mobile-onboarding-design.md) | 引导页 | V20（小禾一句式引导） |
| [Home V23](specs/2026-05-26-flutter-mobile-home-design.md) | 首页 | V23（今日编排入口） |
| [Home A/B 细化](specs/2026-05-28-flutter-mobile-home-ab-prototype-refined.md) | 首页 A/B | B 方向（场景导师）推荐 |
| [Practice](specs/2026-05-26-flutter-mobile-practice-design.md) | 练习页 | 当前一句执行 |
| [Discover V1](specs/2026-05-28-flutter-mobile-discover-design.md) | 发现页 | 场景短语库浏览 |
| [Garden V1](specs/2026-05-28-flutter-mobile-garden-design.md) | 花园页 | 真实练习痕迹 |
| [Garden V2](specs/2026-05-28-flutter-mobile-garden-v2-design.md) | 花园页 | 芭芭农场式单株成长 |
| [Growth V1](specs/2026-05-28-flutter-mobile-growth-design.md) | 成长页 | 温暖回顾 |
| [Growth V2](specs/2026-05-28-flutter-mobile-growth-v2-design.md) | 成长页 | 微信读书式多维度 |
| [Shell V2](specs/2026-05-28-flutter-mobile-shell-v2-design.md) | 导航框架 | 四 Tab + "我"页面 |
| [Auth](specs/2026-05-26-flutter-mobile-auth-login-design.md) | 登录/注册 | 渐进披露 |

### 跨页面文档

| 文件 | 说明 |
|------|------|
| [组件规范](specs/2026-05-28-component-spec.md) | 13 个共享组件的 token 驱动规格 |
| [一致性审查](specs/2026-05-28-cross-page-consistency-audit.md) | 跨页面视觉和交互一致性检查 |
| [全页面决策汇总](specs/2026-05-28-all-pages-design-decisions-summary.md) | 8 个页面的 50+ 项设计决策 |
| [Onboarding 讨论汇总](specs/2026-05-28-onboarding-v21-discussion-summary.md) | Onboarding 18 项决策的讨论过程 |
| [Home A/B 用户测试](specs/2026-05-26-flutter-mobile-home-ab-prototype-user-test-design.md) | A/B 测试设计 |
| [组件规范技术审查](specs/2026-05-29-component-spec-tech-review.md) | 组件规范工程可行性审查 |
| [Flutter UI 库调研（2026）](specs/2026-05-31-flutter-ui-library-landscape-2026.md) | Flutter UI 组件库现状与候选对比 |
| [InputField 库评估](specs/2026-05-31-inputfield-library-evaluation.md) | 输入组件库评估与接入建议 |
| [提取组件库替换评估](specs/2026-06-01-extracted-components-library-replacement-eval.md) | 已提取组件的替换成本与风险评估 |

### 已归档（Superseded）

| 文件 | 说明 |
|------|------|
| [Shell 导航设计（归档）](specs/archived/2026-05-28-flutter-mobile-shell-nav-design.md) | 已被 [Shell V2](specs/2026-05-28-flutter-mobile-shell-v2-design.md) superseded |

---

## 架构与工程

| 文件 | 说明 |
|------|------|
| [架构设计](specs/2026-05-28-flutter-mobile-architecture-design.md) | Flutter mobile 完整架构（模块/状态/数据/路由） |
| [Flutter Skill 审查](specs/2026-05-28-flutter-skill-review-summary.md) | 10 个 Flutter Skill 的 18 项改进 |
| [CI/CD 流水线](specs/2026-05-28-cicd-pipeline.md) | GitHub Actions + 测试 + 构建 + 部署 |
| [安全合规](specs/2026-05-28-security-compliance.md) | COPPA + 数据加密 + API 安全 |
| [性能优化](specs/2026-05-28-performance-optimization.md) | 启动/内存/帧率/网络/包大小优化 |

---

## 产品策略

| 模块 | 说明 |
|------|------|
| 用户留存 | 触发×动机×能力×奖励框架 |
| 触发机制 | 时段/场景/进度/回归/文案 5 种触发 |
| 动机/奖励 | 即时/短期/长期 3 层 + 9 个里程碑 |
| 内容策略 | 本地句库+LLM 生成+推荐+质量控制 |
| 竞品定位 | 场景壁垒+内容壁垒+习惯壁垒+数据壁垒 |
| 用户研究 | 可用性测试+日记研究+A/B 测试+访谈 |

详见 [全会话产出汇总](specs/2026-05-28-full-session-output-summary.md)

---

## HTML 原型

### 本次会话产出（11 个）

| 原型 | 路径 | 关键特性 |
|------|------|---------|
| Onboarding V21 | `.superpowers/brainstorm/onboarding-v21/` | 微交互+转场动画+声源统一 |
| Home A/B | [specs/2026-05-28-home-ab-prototype.html](specs/2026-05-28-home-ab-prototype.html) | Side-by-side 对比 |
| Practice 独立 | `.superpowers/brainstorm/practice/` | 完整练习流程 |
| Auth V11 | `.superpowers/brainstorm/auth/` | 合并登录/注册 |
| Garden V2 | `.superpowers/brainstorm/garden/` | 芭芭农场式单株成长 |
| Growth V2 | `.superpowers/brainstorm/growth/` | 微信读书式多维度 |
| Shell V2 | `.superpowers/brainstorm/shell/` | "我"页面+设置 |
| Discover V1 | `.superpowers/brainstorm/discover/` | 短语列表版 |
| Discover V2 | `.superpowers/brainstorm/discover/` | 场景指南版 |
| Settings | `.superpowers/brainstorm/settings/` | 6 个子页面 |
| Home B | `.superpowers/brainstorm/home/` | 场景导师方向 |

### 历史原型（V20 及之前）

| 原型 | 路径 |
|------|------|
| Onboarding V11-V20 | `.superpowers/brainstorm/78550-1779749108/content/` |
| Auth V7-V10 | `.superpowers/brainstorm/78550-1779749108/content/` |
| Flow V1-V6 | `.superpowers/brainstorm/78550-1779749108/content/` |

---

## 其他文档

| 文件 | 说明 |
|------|------|
| [QA 安装 APK 与根因调试设计](specs/2026-05-25-qa-install-apk-and-debug-root-cause-design.md) | QA 环境配置 |
| [Admin Web 回归收敛设计](specs/2026-05-24-admin-web-regression-convergence-design.md) | Admin Web 回归测试 |

---

## 文档统计

| 类别 | 数量 |
|------|------|
| 设计 Spec 文档 | 20+ 份 |
| HTML 原型 | 11 个（本次）+ 历史版本 |
| 产品策略模块 | 6 个 |
| 工程文档 | 5 份 |
| 总行数 | 10,000+ 行 |
