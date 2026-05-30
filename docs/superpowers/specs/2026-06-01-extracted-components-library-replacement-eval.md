# 已抽取组件「流行库替换」评估（工具评估师）

- 日期：2026-06-01
- 范围：`mobile/lib/app/widgets/` 下 15 个共享组件
- 方法：逐个判定职责 → 区分「品牌绑定外观」与「通用交互/动效」→ 仅对通用类用 2026 主流库交叉验证（pub.dev + Flutter Gems + 社区对比）
- 指导原则（用户裁定）：不造轮子，用优秀现成库降本降 bug——但**前提是不破坏 Warm Paper 品牌一致性**（与 2026-05-31 InputField 评估同口径：品牌外观层保留自研）

## 结论速览

| 组件 | 职责 | 裁定 | 推荐库 / 理由 |
|---|---|---|---|
| app_celebration_overlay | CustomPaint 自研彩带 | **强烈建议替换** | `confetti`（pub.dev 顶级、物理参数可控）；纸屑视觉非品牌核心，自研 painter 维护成本高 |
| app_shimmer | AnimatedBuilder 自研微光骨架 | **建议替换** | `skeletonizer`（2026 社区首选：包裹真实布局自动生成骨架，改版不失配）；保守可选 `shimmer`（去事实标准）|
| app_seed_sprout | V21 定制发芽动画 | 有条件替换 | 仅当设计提供 Lottie/Rive 资产时改用 `lottie`/`rive`；否则保留（属品牌专属动效）|
| app_scale_button | 按压 scale(0.95) 动画 | **保留** | 仅 1.8KB、已尊重 reduce-motion；引库（`flutter_animate`）收益≈0，徒增依赖 |
| app_haptics | 包裹 `HapticFeedback` | **保留** | 0.4KB，直接封装 SDK；`gaptic` 等无实质增益 |
| app_step_progress | 多步进度条 | **保留** | 1.2KB 简单条；第三方 stepper 体积/样式反而难对齐令牌 |
| app_input_field | 输入框（§2.13） | **保留** | 见 2026-05-31 评估：shadcn/forui 极简风与品牌冲突 |
| app_mentor_bubble | 导师气泡 | **保留** | 品牌核心 UI，视觉契约被测试锁定 |
| app_english_phrase | 英文主显示（Fraunces）| **保留** | 品牌最核心视觉元素 |
| app_surface_card | 令牌卡片（§2.11）| **保留** | 纯设计令牌外观 |
| app_banner | 统一横幅 | **保留** | 替代 8+ 私有变体，已是内部收敛 |
| app_audio_button | 发音按钮外观层 | **保留** | 仅外观；播放状态机在调用点 |
| xiaohe_fab | 小禾 FAB | **保留** | 品牌 FAB，沿用主题 |
| app_toast | Toast 入口 | **保留** | 仅 0.7KB 包裹主题 snackBarTheme；`toastification` 等会引入非品牌样式 |
| app_empty_state | 空状态 | **保留** | 2KB 简单组合，令牌绑定 |

## 可落地的两个替换

### 1. confetti 替换 app_celebration_overlay（首选）
- 依赖：`confetti`（成熟、维护活跃）
- 收益：删除自研 `_ConfettiPainter`，物理（速度/角度/重力/数量）开箱可调
- 风险：低——纸屑非品牌契约；颜色仍可传 Warm Paper accent 色板
- 工作量：小（替换 overlay 内部绘制，外部 API 可保持不变）

### 2. skeletonizer 替换 app_shimmer（建议）
- 依赖：`skeletonizer`（2026 社区首选）或保守的 `shimmer`
- 收益：包裹真实布局自动出骨架，页面改版骨架不再手工同步
- 风险：中——需把现有「4px 灰条 → AppShimmer」的调用点改为包裹真实子树；微光颜色需对齐 bgSunken/outlineSoft
- 工作量：中（涉及多处加载占位调用点）

## 不建议替换的理由（统一口径）
- 体积已极小（haptics/scale/step/toast 均 <2KB）：引库的依赖与升级成本 > 收益。
- 品牌外观层（bubble/english/card/banner/audio/fab/input/empty）：第三方库的默认美学与 Warm Paper 冲突，替换会引入「AI 通用感」并破坏已锁定的视觉契约。

## 待人工裁定
1. 是否采用 confetti（强候选，低风险）？
2. shimmer 替换选 `skeletonizer`（更现代）还是 `shimmer`（更轻、改动小）？
3. seed_sprout 是否计划提供 Lottie/Rive 资产？否则维持自研。
