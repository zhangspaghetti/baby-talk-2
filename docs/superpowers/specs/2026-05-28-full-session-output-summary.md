# BabyTalk 全会话产出汇总

日期：2026-05-28
状态：已完成

---

## 1. 设计产出

### 1.1 设计 Spec 文档（14+ 份）

| 文件 | 页面 | 状态 |
|------|------|------|
| `2026-05-28-flutter-mobile-onboarding-v21-design.md` | Onboarding V21 | 最终确认 |
| `2026-05-26-flutter-mobile-home-design.md` | Home V23 | 确认 |
| `2026-05-28-flutter-mobile-home-ab-prototype-refined.md` | Home A/B | 确认 |
| `2026-05-26-flutter-mobile-practice-design.md` | Practice | 确认 |
| `2026-05-28-flutter-mobile-discover-design.md` | Discover V1 | 确认（待升级为 V2） |
| `2026-05-28-flutter-mobile-garden-v2-design.md` | Garden V2 | 最终确认 |
| `2026-05-28-flutter-mobile-growth-v2-design.md` | Growth V2 | 最终确认 |
| `2026-05-28-flutter-mobile-shell-v2-design.md` | Shell V2 | 最终确认 |
| `2026-05-26-flutter-mobile-auth-login-design.md` | Auth V10 | 确认（待升级为 V11） |
| `2026-05-28-flutter-mobile-shell-v2-design.md` | Shell V2 | 最终确认 |
| `2026-05-28-component-spec.md` | 组件规范 | 确认 |
| `2026-05-28-cross-page-consistency-audit.md` | 一致性审查 | 确认 |
| `2026-05-28-onboarding-v21-discussion-summary.md` | Onboarding 讨论汇总 | 确认 |
| `2026-05-28-all-pages-design-decisions-summary.md` | 全页面决策汇总 | 确认 |

### 1.2 HTML 原型（11 个）

| 原型 | 路径 | 关键特性 |
|------|------|---------|
| Onboarding V21 | `.superpowers/brainstorm/onboarding-v21/` | 微交互+转场动画+声源统一 |
| Home A/B | `docs/superpowers/specs/` | Side-by-side 对比 |
| Practice 独立 | `.superpowers/brainstorm/practice/` | 完整练习流程 |
| Auth V11 | `.superpowers/brainstorm/auth/` | 合并登录/注册 |
| Garden V2 | `.superpowers/brainstorm/garden/` | 芭芭农场式单株成长 |
| Growth V2 | `.superpowers/brainstorm/growth/` | 微信读书式多维度 |
| Shell V2 | `.superpowers/brainstorm/shell/` | "我"页面+设置 |
| Discover V1 | `.superpowers/brainstorm/discover/` | 短语列表版 |
| Settings | `.superpowers/brainstorm/settings/` | 6 个子页面 |
| Home B | `.superpowers/brainstorm/home/` | 场景导师方向 |
| Discover V2 | `.superpowers/brainstorm/discover/` | 场景指南版 |

---

## 2. 产品策略产出

### 2.1 用户留存框架

```
留存 = 触发 × 动机 × 能力 × 奖励
```

| 模块 | 核心内容 |
|------|---------|
| **触发** | 时段/场景/进度/回归/文案 5 种触发 |
| **动机** | 即时/短期/长期 3 层动机 + 9 个里程碑 |
| **能力** | 低门槛/智能推荐/离线/记忆/单手 5 项 |
| **奖励** | 即时奖励/进度奖励/成长奖励/里程碑奖励 |

**目标指标：**
- Day 1 留存率：>60%
- Day 7 留存率：>30%
- Day 30 留存率：>15%
- 每日活跃次数：>2 次
- 每句完成率：>80%

### 2.2 触发机制

| 类型 | 时机 | 文案风格 |
|------|------|---------|
| 时段触发 | 喂饭/睡前等照护时间 | "该说一句了" |
| 场景触发 | 到达推荐场景时间 | "睡前时间到了" |
| 进度触发 | 花快开花了/里程碑临近 | "再坚持一下" |
| 回归触发 | 3天没打开 | "小禾想你了" |
| 内容触发 | 新场景/新句子可用 | "有新内容" |

**频率控制：** 同一类型触发每天最多 1 次；不同类型的触发如果同时触发，只显示优先级最高的一个。

### 2.3 动机/奖励

| 层级 | 动机 | 时间尺度 |
|------|------|---------|
| 即时 | "我说了一句" | 秒 |
| 短期 | "花在长大" | 天 |
| 长期 | "我坚持了很久" | 周/月 |

里程碑：第1句→首次场景→累计10句→覆盖3场景→累计25句→覆盖6场景→累计50句→坚持7天→坚持30天

### 2.4 内容策略

- Phase 1：本地句库（60-90 句）+ LLM 动态生成
- Phase 2：用户贡献 + 专家编辑
- 推荐系统：时段×场景×历史×难度
- 质量控制：L1 自动过滤 → L2 LLM 审核 → L3 人工抽查 → L4 用户反馈

### 2.5 竞品定位

| 维度 | BabyTalk 做法 | 竞品做法 |
|------|-------------|---------|
| 使用场景 | 照护中自然发生 | 专门的学习时间 |
| 目标用户 | 家长（0-3 岁） | 孩子或成人 |
| 内容形式 | 一句式短语 | 课程/动画/游戏 |
| 激励方式 | 成长感（花园） | 游戏化（分数/等级） |

差异化壁垒：场景壁垒 + 内容壁垒 + 习惯壁垒 + 数据壁垒

### 2.6 用户研究

| 方法 | 目标 | 时机 |
|------|------|------|
| 可用性测试 | 验证交互设计 | 原型完成后 |
| 日记研究 | 验证留存机制 | 内测阶段 |
| A/B 测试 | 验证设计方向 | 公测阶段 |
| 访谈 | 深度理解用户 | 任何阶段 |

---

## 3. 设计决策汇总

### 3.1 Onboarding V21（18 项决策）

| # | 决策 | 方案 |
|---|------|------|
| 1 | 场景选择 | 大按钮纵向列表（非 2×3 网格） |
| 2 | 默认选中 | 根据时段智能推断 |
| 3 | 句卡样式 | 无边框，英文直接浮出 |
| 4 | 发音播放 | 小图标按钮（🔊） |
| 5 | 小禾气泡 | 场景动态文案 |
| 6 | 声源统一 | 所有引导融入小禾气泡 |
| 7 | 去掉"开始一句" | 场景选中后自动进入练习 |
| 8 | 宝宝反应 | 图标+文字，2.5-3s 自动跳转 |
| 9 | 结束态 | 种子萌芽动画+动态文案系统 |
| 10 | 触觉反馈 | 场景/说完了/反应 3 处 |
| 11 | 按钮动画 | scale(0.95-0.97) 150-200ms |
| 12 | 页面转场 | 元素级联动，stagger 50-80ms |
| 13 | 拇指区域 | 主要操作在底部 1/3 |
| 14 | 触控目标 | ≥44px |
| 15 | prefers-reduced-motion | 全部支持 |
| 16 | 结束态按钮 | "先到这里"（非"回到场景"） |
| 17 | 使用提示 | 卡片内增加 usageHint |
| 18 | 排序替代换一批 | 最常用/最新/全部 |

### 3.2 Home B（6 项决策）

| # | 决策 | 方案 |
|---|------|------|
| 1 | 首屏锚点 | 照护时刻（时段+场景） |
| 2 | 小禾角色 | 主动导师（不是被动说明） |
| 3 | 照护时刻生成 | 时段词+时长+场景动作 |
| 4 | 小禾建议 | 气泡式，≤2 行 |
| 5 | 快速救援 | 纵向列表（与 Onboarding 一致） |
| 6 | 完成后变化 | toast+CTA 变化+花园摘要（简化方案） |

### 3.3 Garden V2（可配置参数）

| 参数 | 默认值 |
|------|--------|
| fertilizer.perPhrase | 1 |
| fertilizer.bonusOnResponse | 1 |
| fertilizer.dailyCap | 10 |
| growth.stages | 种子(0)/发芽(3)/含苞(10)/盛开(25)/结果(50) |

### 3.4 Growth V2

5 维度 tab：周/月/年/总/旅程

### 3.5 Shell V2

底部 Tab 改为：首页/发现/花园/我

### 3.6 Auth V11

合并登录/注册 + 隐形验证 + OTP 自动填充

---

## 4. 原型产出

### 4.1 设计验证结果

| 原型 | 评分 | 关键验证点 |
|------|------|-----------|
| Onboarding V21 | A | 声源统一、萌芽动画、转场流畅 |
| Practice | A | 无边框句卡、小禾气泡、底部导航 |
| Auth V11 | A | 品牌清晰、渐进披露、信任文案 |
| Discover V2 | A | 场景指南+活动+推荐 |
| Garden V2 | A | 种子阶段+施肥+领取 |
| Growth V2 | A | 5 维度 tab+柱状图+花园联动 |
| Shell V2 | A | "我"页面+设置+关于 |
| Home B | A | 照护时刻+小禾+快速救援 |
| Settings | A | 6 个子页面完整交互 |

### 4.2 设计审查发现

| 页面 | 发现数 | 严重度 |
|------|--------|--------|
| Onboarding V21 | 5 | 1H, 2M, 2P（修复 4.5） |
| Practice | 7 | 2H, 3M, 2P |
| Discover V1 | 8 | 2H, 4M, 2P |

---

## 5. 行业研究参考

| 产品 | 关键学习 |
|------|---------|
| Duolingo | 引导路径设计、角色陪伴 |
| Huckleberry | 动态日程调整、数据追踪 |
| Parent Sense | Responsive Routine |
| 芭芭农场 | 任务→肥料→施肥→成长循环 |
| 微信读书 | "我"页面布局、多维度统计 |
| Authgear | 登录 UX 最佳实践 |
| BabyScroll | 安静、有意图的设计 |
| WeChat Read | "我"页面参考截图 |

---

## 6. 待完成项

| 项目 | 状态 |
|------|------|
| 架构设计文档 | 🔄 进行中 |
| 跨页面一致性审查 | ⏳ 待启动 |
| Flutter 实现阶段 | ⏳ 待启动 |
