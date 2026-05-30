# InputField 抽取——开源组件库评估报告

> **角色**：工具评估师（待技术专家审核）
> **日期**：2026-05-31
> **关联**：[组件规范 §2.13](./2026-05-28-component-spec.md) ·
> [配套技术评审](./2026-05-29-component-spec-tech-review.md)
> **状态**：⏳ 待技术专家（/plan-eng-review）审核

---

## 1. 背景与触发

在执行规范 §2.13「InputField 抽取」时发现：mobile 端 10 处 `TextField`
调用点**并非机械等价**，统一封装为单一 `AppInputField` 会引入真实**功能回归**
（登录自动填充、OTP 长度限制、多行输入、卡片内无边框样式等）。

为避免「重复造轮子」，先调研市面优秀开源 Flutter 输入/表单组件库，对比评估后再
由技术专家审核决定采用方案。

## 2. 调用点兼容性矩阵（10 处）

| # | 位置 | 特殊需求 | 自建单一组件能否覆盖 |
|---|------|---------|---------------------|
| 1 | `onboarding_screen.dart:314` | labelText + hintText + key | ✅ |
| 2 | `account_entry_screen.dart:694` | label/hint/errorText/key | ✅ |
| 3 | `account_entry_screen.dart:708` | label/hint/errorText/key | ✅ |
| 4 | `discover_screen.dart:371` 搜索框 | 搜索图标 + 清除键 + 18px 内距 + 15px 占位 | ⚠️ 需 clearKey；收敛 12/16 为视觉变更 |
| 5 | `auth_screen.dart:155` 联系方式 | autofillHints / helperText / prefixText `+86 ` | ❌ 缺 3 属性 |
| 6 | `auth_screen.dart:776` 验证码 | maxLength6 / OTP autofill / 等宽 letterSpacing / counterText / resend 按钮 | ❌ 高度定制 |
| 7 | `auth_screen.dart:878` 密码 | obscure + autofillHints / helperText / 显隐切换 | ⚠️ 缺 autofill/helper |
| 8 | `mentor_panel_sheet.dart:312` | minLines3 / maxLines5 / maxLength | ❌ 缺多行 + maxLength |
| 9 | `baby_profile_screen.dart:73` | `InputBorder.none`（卡片内无边框）+ maxLength12 | ❌ 恒有边框 → 视觉回归 |
| 10 | `home_b_temporary_scene_sheet.dart:220` | accentDark 聚焦 / r16 / 无搜索图标 | ⚠️ 收敛 r8 为视觉变更 |

**结论**：仅 3 处可零改动直迁；7 处需扩展组件或定制。

## 3. 候选库对比（pub.dev 数据，2026-05-31）

### 3.1 表单状态 / 校验类（不替换视觉）

| 包 | Likes | 下载 | License | Pub 分 | 评估 |
|----|-------|------|---------|--------|------|
| `flutter_form_builder` + `form_builder_validators` | 2796 | 81.8k | MIT | 160 | ⭐⭐⭐⭐ 保留 Material TextField，仅去样板 + 复用校验，不改视觉；生态组织维护 |
| `reactive_forms`（+ widgets 生态） | 中 | 中 | MIT | 160 | ⭐⭐⭐ Angular FormGroup 风格，响应式强但学习/改造成本高 |
| `moform` | 11 | 3.5k | MIT | 160 | ⭐⭐ 轻封装 TextFormField，免 controller，生态小 |
| `form_validator` | 240 | 11.4k | MIT | 160 | ⭐⭐⭐ 纯校验链，极轻量，可与现有组件叠加 |

### 3.2 设计组件套件（替换视觉）

| 包 | Likes | 下载 | License | Pub 分 | 评估 |
|----|-------|------|---------|--------|------|
| `forui`（shadcn 风） | 391 | 11.2k | MIT | 160 | ⚠️ 含 text_field/otp_field/autocomplete/date_field/time_field 全套，但**强制 shadcn 美学**，与「暖纸」设计系统冲突 |
| `shadcn_ui` | 高 | 高 | MIT | — | ⚠️ 同上，整体换肤才划算 |

### 3.3 专用 OTP / PIN

| 包 | Likes | 下载 | License | Pub 分 | 评估 |
|----|-------|------|---------|--------|------|
| `pinput` | **3461** | **459k** | MIT | 160 | ⭐⭐⭐⭐⭐ SMS 自动填充 / 2FA 业界标准，精确解决 auth 验证码框 |
| `pin_code_fields` | 2367 | 336k | MIT | 160 | ⭐⭐⭐⭐ 备选，headless core 可定制 |

## 4. 评估师核心判断

1. **本项目已有成熟自定义设计系统**（Warm Paper tokens + `BabyTalkColors`
   ThemeExtension + 13 个 `App*` 共享组件）。规范 §2.13 目标是「向现有 token
   收敛」，**不是更换设计语言**。
2. ❌ **不建议引入 forui / shadcn_ui**：其核心价值是「自带一套视觉」，而本项目恰恰
   要保留自有视觉；混用造成设计割裂，迁移成本远超 InputField 抽取本身。
3. ✅ **真正值得引库的点是 OTP 验证码框**：等宽 + SMS 自动填充自实现复杂易错，
   `pinput`（459k 下载）是业界标准，强烈建议采用。
4. 🟡 **表单校验 / 样板**：若团队厌烦 InputDecoration 样板，可选
   `flutter_form_builder`（保留 Material 视觉，仅去样板）；但仅 10 处字段，
   一个薄主题封装可能更划算——引库的边际收益需技术专家权衡。

## 5. 推荐方案（待技术专家定夺）

**混合制**：

| 场景 | 方案 | 理由 |
|------|------|------|
| auth 验证码框（#6） | 引入 `pinput` | 避免造轮子，SMS 自动填充刚需 |
| 通用输入框（#1/2/3/4/7/8/10） | 薄封装 `AppInputField` 对齐 Warm Paper token（按需补 maxLength/minLines/helperText/autofillHints/prefixText/clearKey）；或 `flutter_form_builder` 字段 + 自定义 decoration | 保留设计系统，去样板 |
| baby_profile 卡片内框（#9） | 保留现状 / `AppInputField` 加 `borderless` 选项 | 卡片内无边框是刻意设计 |
| 整套 UI 套件（forui 等） | **不采用** | 与现有设计系统冲突 |

## 6. 待技术专家审核的开放问题

1. 是否接受引入 `pinput` 作为唯一新增 UI 依赖？（供应链/包体积/许可证）
2. 通用输入框走「薄封装」还是「flutter_form_builder」？（10 处规模下边际收益）
3. `discover`/`home_b` 收敛 r8 是否接受随之而来的视觉变更（需 golden 复核）？
4. baby_profile 无边框框：保留现状还是给 `AppInputField` 增 `borderless` 变体？

---

*本报告由工具评估师产出，最终方案以技术专家（/plan-eng-review）审核结论为准。*
