# BabyTalk Flutter Mobile — 全页面设计决策汇总

日期：2026-05-28
状态：最终确认
覆盖范围：8 个页面 + 1 个组件规范 + 1 个一致性审查

---

## 1. Onboarding V21

**定位：** 场景优先 + 一句式引导

| 决策 | 方案 |
|------|------|
| 场景选择 | 大按钮纵向列表（非 2×3 网格），6 个场景 |
| 默认选中 | 根据时段智能推断 |
| 句卡样式 | 无边框，英文直接浮出 |
| 发音播放 | 小图标按钮（🔊），不是独立按钮行 |
| 小禾气泡 | 场景动态文案，声源统一 |
| 去掉"开始一句" | 场景选中后自动进入练习 |
| 宝宝反应 | 图标+文字，2.5-3s 自动跳转 |
| 结束态 | 种子萌芽动画 + 动态文案系统 |
| 微交互 | 触觉反馈、按钮缩放、元素级联动转场 |

**Spec:** `2026-05-28-flutter-mobile-onboarding-v21-design.md`
**原型:** `qa-mobile-onboarding-v21-scene-first.html`

---

## 2. Home B 方向

**定位：** 照护时刻 + 小禾导师 + 快速救援

| 决策 | 方案 |
|------|------|
| 首屏锚点 | 照护时刻（时段+场景），不是短语卡片 |
| 小禾角色 | 主动导师（不是被动说明） |
| 照护时刻生成 | 时段词 + 时长 + 场景动作 |
| 小禾建议 | 气泡式，≤2 行 |
| 快速救援 | 纵向列表（与 Onboarding 一致） |
| 完成后变化 | toast + CTA 变化 + 花园摘要（简化方案） |

**Spec:** `2026-05-28-flutter-mobile-home-ab-prototype-refined.md`
**原型:** `2026-05-28-home-ab-prototype.html`

---

## 3. Practice

**定位：** 当前一句的执行

| 决策 | 方案 |
|------|------|
| 句卡 | 无边框，英文直接浮出 |
| 发音 | 小图标按钮 |
| 主按钮 | "说完了"固定底部，56px |
| 次级按钮 | "换一句"+"结束"文字按钮 |
| 反应 | 图标+文字，按场景变化 |
| 自动跳转 | 2.5-3s + 可见倒计时 |

**Spec:** `2026-05-26-flutter-mobile-practice-design.md`

---

## 4. Discover 发现页

**定位：** 场景短语库浏览

| 决策 | 方案 |
|------|------|
| 搜索 | 轻量内联搜索 |
| 筛选 | 横滑 pill |
| 短语卡片 | 单列，+使用提示 |
| 排序 | 替代"换一批"（最常用/最新/全部） |
| 与 Home 区分 | Home=轻活动，Discover=纯短语 |

**Spec:** `2026-05-28-flutter-mobile-discover-design.md`

---

## 5. Garden V2 花园页

**定位：** 芭芭农场式单株成长

| 决策 | 方案 |
|------|------|
| 核心循环 | 说英文→得肥料→领取→施肥→花成长 |
| 成长阶段 | 种子→发芽→含苞→盛开→结果 |
| 肥料获取 | 每说一句产生 1 包 |
| 领取 | 手动领取（制造参与感） |
| 施肥 | 手动点击施肥按钮 |
| 视觉 | 单株花，CSS/SVG 动画 |

**Spec:** `2026-05-28-flutter-mobile-garden-v2-design.md`

---

## 6. Growth V2 成长页

**定位：** 微信读书式多维度回顾

| 决策 | 方案 |
|------|------|
| 维度切换 | 周/月/年/总/旅程 5 个 tab |
| 每日图表 | 柱状图（轻量） |
| 里程碑 | 旅程 tab 内的时间线 |
| 花园联动 | 每个维度底部显示花园状态 |
| 下一步建议 | 周/月维度底部的温和建议 |

**Spec:** `2026-05-28-flutter-mobile-growth-v2-design.md`

---

## 7. Shell V2 导航

**定位：** 四 Tab + "我"页面 + 设置独立页

| 决策 | 方案 |
|------|------|
| 底部 Tab | 首页/发现/花园/我 |
| "我"页面 | 头像+花园状态+成长数据+功能网格 |
| 设置 | 独立页面（齿轮图标进入） |
| 小禾 FAB | 首页和花园隐藏，其他页面显示 |
| Drawer | 移除，改为"我"页面入口 |

**Spec:** `2026-05-28-flutter-mobile-shell-v2-design.md`

---

## 8. Auth V11 登录页

**定位：** 合并登录/注册 + 隐形验证

| 决策 | 方案 |
|------|------|
| 首屏 | 手机号输入 + "下一步" |
| 登录/注册 | 合并（系统自动判断新/旧用户） |
| 验证码 | 6 位分格 + 自动填充 + 60s 倒计时 |
| 密码登录 | 次要入口保留 |
| 人机校验 | 隐形验证优先 |
| 品牌 | 顶部 logo + 一句价值说明 |

**Spec:** `2026-05-26-flutter-mobile-auth-login-design.md`（待更新为 V11）

---

## 9. 设置页面

**定位：** 安静的、快速改完的

| 模块 | 内容 |
|------|------|
| 提醒设置 | 开关 + 时间选择器（默认关闭） |
| 宝宝档案 | 昵称（必填）+ 月龄（可选） |
| 照护者偏好 | 妈妈/爸爸/老人切换 |
| 播放偏好 | 音量滑块 + 语速三档 |
| 帮助与反馈 | 常见问题 + 联系我们 |
| 关于 | 版本 + 协议 + 许可 |

---

## 10. 组件规范

**13 个组件的统一 token 驱动规格：**

| 组件 | 关键规格 |
|------|---------|
| ScenePill | 32px 高，--radius-full，选中态 --accent |
| PrimaryCTA | 56px 高，--radius-md，--accent 纯色 |
| SecondaryButton | 44px 高，--radius-md，边框 |
| MentorAvatar | 40px 显示 / 28px 内联 |
| MentorBubble | surface bg，18px radius |
| EnglishPhrase | Fraunces，--english 颜色 |
| AudioButton | 40px 高，--sage-soft bg |
| BabyReaction | 图标+文字，3 种语义色 |
| BottomNav | 82px 高，4 Tab |
| XiaoheFAB | 56x56px，--shadow-md |
| Card | --bg-surface，--shadow-sm |
| Toast | sage-soft bg，1.5-3s |
| InputField | --bg-sunken，--radius-sm |

**Spec:** `2026-05-28-component-spec.md`

---

## 11. 一致性审查结果

**总评：B** — 3 个 High + 10 个 Medium 不一致

**已通过：** 场景名称列表、触控目标、"说完了"文案、prefers-reduced-motion

**待修复：** 底部导航 Tab 命名、导航栏高度、FAB 可见性、字号、圆角、阴影颜色等

**Spec:** `2026-05-28-cross-page-consistency-audit.md`

---

## 12. 产出物清单

| 类型 | 数量 | 文件 |
|------|------|------|
| 设计 Spec | 12 份 | docs/superpowers/specs/ |
| HTML 原型 | 3 版 | .superpowers/brainstorm/ |
| 设计决策 | 30+ 项 | 本文件汇总 |
| 行业研究 | 6 个产品 | Duolingo, Huckleberry, Parent Sense, 芭芭农场, 微信读书, Authgear |
| 组件规范 | 13 个组件 | component-spec.md |
| 一致性审查 | 13 个发现 | consistency-audit.md |
