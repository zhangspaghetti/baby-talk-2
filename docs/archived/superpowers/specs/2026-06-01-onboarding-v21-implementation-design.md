# Onboarding V21 实现设计

日期：2026-06-01
状态：设计已确认
前序规格：[Onboarding V21 交互结论](2026-05-28-flutter-mobile-onboarding-v21-design.md)

## 1. 背景

V21 在 V20 基础上全面重构 onboarding 流程：从聊天式引导（名字→年龄→预览）改为场景优先式引导（场景选择→练习→反应→结束）。现有实现基于 `OnboardingScreen` + `OnboardingNotifier` 的单页面架构，需要完全替换。

## 2. 架构方案

采用**路由式多页面**方案（方案 B）：拆成独立页面，通过 `go_router` 串联，Riverpod 管理共享状态。

### 2.1 页面与路由

| 路径 | 页面 | 职责 | 转场 |
|------|------|------|------|
| `/onboarding/name` | 名字输入 | 收集昵称，一步完成 | 默认 |
| `/onboarding/scene` | 场景选择 | 6 场景纵向列表，智能默认，年龄后置入口 | 从右滑入 250ms |
| `/onboarding/practice` | 练习页 | 展示句子，记录反应，管理句池循环 | 从右滑入 250ms |
| `/onboarding/complete` | 结束态 | 萌芽动画，动态文案，完成/继续选择 | 从下推入 300ms |

### 2.2 状态管理

- **跨页面共享状态：** `OnboardingSessionNotifier`（Riverpod StateNotifier）管理 `OnboardingSession`
- **页面本地状态：** 各页面管理自己的 UI 状态（动画控制器、文本输入、倒计时计时器）
- **句池服务：** `ScenePhraseService` 提供按场景的本地静态短语

## 3. 数据模型

### 3.1 PracticeScene 枚举

```dart
enum PracticeScene {
  feeding,   // 喂饭
  drinking,  // 喝水
  diaper,    // 换尿布
  bath,      // 洗澡
  bedtime,   // 睡前
  outing,    // 出门
}
```

每个场景关联：
- 场景中文名（用于 UI 显示）
- 智能默认时段映射
- 小禾气泡动态文案
- 结束态主标题文案
- 本地句池（3-5 句）

### 3.2 BabyReaction 枚举

```dart
enum BabyReaction {
  responded,   // 😊 有回应
  calmed,      // 😌 安静了
  noResponse,  // 😐 没反应
}
```

### 3.3 PracticeRecord

```dart
class PracticeRecord {
  final String phraseId;
  final String english;
  final String chinese;
  final PracticeScene scene;
  final BabyReaction? reaction;
  final DateTime practicedAt;
}
```

### 3.4 OnboardingSession

```dart
class OnboardingSession {
  String childName;
  PracticeScene? selectedScene;
  List<PracticeRecord> records;
  OnboardingAgeBucket? ageBucket;
}
```

## 4. 页面设计

### 4.1 名字输入页

**路径：** `/onboarding/name`

**页面结构：**
1. 顶部栏：`小禾老师`，无返回（首屏）
2. 小禾气泡：`先告诉小禾，宝宝叫什么？`
3. 输入框：昵称输入，最大 12 字
4. 底部主按钮：`下一步`，≥56px

**交互：**
- 输入昵称后点"下一步"写入 `OnboardingSession.childName`，导航到场景选择
- 名字为空时按钮禁用
- 支持键盘 done 直接提交
- 名字持久化到 `OnboardingSession`，供结束态动态文案使用

### 4.2 场景选择页

**路径：** `/onboarding/scene`

**页面结构：**
1. 顶部栏：`小禾老师 / 一句就好`，[返回] 左上角
2. 小禾气泡：`选个正在发生的场景，小禾给你一句现在就能说的。`
3. 主标题：`今天先说一句`
4. 提示行：`选个正在发生的场景`
5. 场景列表：纵向 6 行，每行 ≥48px 高
   - 喂饭 / 喝水 / 换尿布 / 洗澡 / 睡前 / 出门
   - 选中态：accent (#FF8C42) + 白色文字
   - 未选中态：暖纸表面 + 细边框
6. 年龄后置入口：底部虚线框按钮 `宝宝多大？可稍后补`
7. 底部次要按钮：`直接给一句`（右上角文字按钮）

**智能默认逻辑：**
- 首次打开：根据本地时间推断
  - 7-9 点 → 喂饭
  - 10-11 点 → 喝水
  - 12-14 点 → 换尿布
  - 15-17 点 → 洗澡
  - 18-21 点 → 睡前
  - 其他 → 出门
- 非首次打开：默认选中上次使用的场景（通过 `OnboardingSnapshotStore` 持久化最近场景，若无记录则按时段推断）

**交互：**
- 选中场景 → 轻触觉反馈 (`HapticFeedback.lightTap()`) → 自动进入练习页（无需确认按钮）
- "直接给一句" → 使用默认场景直接进入练习页
- 年龄按钮 → 展开月龄选择面板（0-6/7-12/13-18/19-36/先跳过）
- 选择年龄后按钮显示已选月龄

**动画：**
- 场景按钮按下：scale(0.95) 150ms ease-out
- 选中进入练习页：选中按钮放大高亮 200ms → 其他按钮淡出 150ms → 页面从右滑入 250ms

### 4.3 练习页

**路径：** `/onboarding/practice`

**页面结构：**
1. 顶部栏：场景名 / `一句就够`，[返回] 左上（回到场景选择，保留已练习记录），[结束] 右上（跳过反应，直接进入结束态）
2. 小禾气泡：场景动态文案（≤15 字）
3. 句子展示区（无边框）：
   - 场景 pill 标签
   - 句序计数（如 1/5）
   - 英文主句：32px，Fraunces 字体
   - 中文释义：15px，柔和色
   - 音频小图标（🔊）放在英文句子旁
4. 底部主按钮：`说完了`，固定底部，≥56px
5. 底部次级按钮：`换一句`、`结束`，文字按钮

**场景动态文案：**
- 喂饭：`喂饭时轻轻说，宝宝会听的。`
- 喝水：`递水的时候说一句就好。`
- 换尿布：`换尿布时说，宝宝反而更安静。`
- 洗澡：`洗澡时说，宝宝会觉得好玩。`
- 睡前：`睡前轻轻说，像讲故事一样。`
- 出门：`出门前说一句，今天就开始了。`

**"说完了"后 → 反应记录内联：**
1. 句子立即保存，显示 `已保存本句`
2. 三个反应按钮（图标 + 文字）依次淡入（stagger 80ms）：
   - 😊 有回应（绿色调）
   - 😌 安静了（蓝色调）
   - 😐 没反应（灰色调）
3. 选后显示反馈文案 + 可见倒计时进度条（2.5-3s）
4. 倒计时期间可点"下一句"跳过，或"结束"取消自动跳转
5. 不选反应则需点击"跳过，下一句"

**反馈文案：**
- 有回应：`记下来了，小禾给你下一句。`
- 安静了：`记下来了，这句可以留着用。`
- 没反应：`没关系，换一句试试。`

**句池管理：**
- `ScenePhraseService` 按场景返回 3-5 句本地短语
- "换一句"从未使用句中随机抽取
- 句池用完后"换一句"灰掉，提示"这个场景的句子都试过了"

**动画：**
- "说完了"按下：scale(0.97) 150ms
- 反应按钮按下：scale(0.95) 200ms
- 反应选中放大：scale(1.05) → 回弹 200ms

### 4.4 结束态

**路径：** `/onboarding/complete`

**页面结构：**
1. 顶部栏：`小禾老师 / 今天已完成`，[返回]
2. 小禾气泡：根据完成数量动态变化
   - 说了 1 句：`第一句最难，你已经开始了。`
   - 说了 2-3 句：`连续说了几句，宝宝有听到的。`
   - 说了 4+ 句：`今天说的比很多家长一周都多。`
3. 种子萌芽动画：`AppSeedSprout`（已有组件），1.5s，结束后文字淡入 0.3s
4. 主标题：根据场景动态变化
   - 喂饭：`喂饭时说的这句，下次还能用。`
   - 睡前：`睡前说的这句，会变成你们的小仪式。`
   - 洗澡：`洗澡时说的这句，宝宝会觉得好玩。`
   - 出门：`出门前说的这句，今天就开始了。`
   - 喝水：`喝水时说的这句，明天还能用。`
   - 换尿布：`换尿布时说的这句，宝宝会慢慢习惯。`
5. 总结固定行：`下次打开，小禾会给你新的一句。`
6. 总结可选追加（根据反应统计）：
   - 有回应句 > 0：`刚才宝宝有回应的那句，可以留着多用几次。`
   - 全部没反应：`有些句子需要宝宝听几次才会有反应，这很正常。`
7. 主按钮：`再来一句` → 回到练习页（同场景，从句池取下一句，已练习记录保留）
8. 次按钮：`先到这里` → 完成 onboarding，保存 `OnboardingSnapshot`，进入首页

**动画转场（练习页 → 结束态）：**
1. "说完了"按钮 → 变为 "✓ 已保存" (200ms)
2. 萌芽从底部生长 (1.5s)
3. 标题 → 萌芽完成后淡入 (300ms)
4. 按钮 → 最后淡入 (200ms)

## 5. ScenePhraseService

本地静态句库，每个场景 3-5 句。

```dart
class ScenePhraseService {
  /// 获取指定场景的所有可用短语
  List<ScenePhrase> getPhrases(PracticeScene scene);

  /// 获取指定场景的随机一句（排除已使用）
  ScenePhrase? getRandomPhrase(PracticeScene scene, Set<String> usedPhraseIds);
}

class ScenePhrase {
  final String phraseId;
  final String english;
  final String chinese;
  final PracticeScene scene;
}
```

句库内容与后端场景标签对齐，初期使用本地 JSON 资源文件。

## 6. 微交互规范

### 6.1 触觉反馈

| 交互点 | 反馈类型 | 时机 |
|--------|---------|------|
| 选中场景 | 轻触觉 (light tap) | 场景按钮按下时 |
| 点击"说完了" | 中触觉 (medium tap) | 保存成功时 |
| 选择反应 | 轻触觉 (light tap) | 反应按钮按下时 |

### 6.2 按钮状态动画

| 按钮 | 按下动画 | 回弹时长 |
|------|---------|---------|
| 场景按钮 | scale(0.95) | 150ms ease-out |
| "说完了" | scale(0.97) | 150ms ease-out |
| 反应按钮 | scale(0.95) | 200ms ease-out |

### 6.3 页面转场

| 转场 | 方向 | 时长 |
|------|------|------|
| 名字 → 场景选择 | 从右滑入 | 250ms ease-out |
| 场景选择 → 练习页 | 从右滑入 | 250ms ease-out |
| 练习页 → 结束态 | 从下推入 | 300ms ease-out |

所有转场支持 `prefers-reduced-motion`：跳过动画，直接切换。

### 6.4 拇指区域优化

主要操作（底部 1/3）：`说完了`、反应按钮
次要操作（顶部 1/3）：`返回`、`结束`、`直接给一句`

## 7. 错误处理

| 场景 | 处理 |
|------|------|
| TTS 失败 | 显示"发音加载失败，点我重试"，点击重试，不自动重试 |
| 短语获取失败 | 本地 fallback 句库 + Toast"网络不佳，已为你准备离线短语" |
| 网络错误 | 离线模式标识 + 仅展示本地短语 |
| 句池耗尽 | "换一句"灰掉 + 提示"这个场景的句子都试过了" |

## 8. 可访问性

1. 触控目标 ≥ 44px，推荐 48dp
2. 小禾头像装饰元素对屏幕阅读器隐藏；气泡需有语义标签
3. 交互元素有明显 focus 状态
4. 支持 prefers-reduced-motion
5. 无横向滚动
6. 反应按钮用图标+文字，不依赖颜色

## 9. 与现有代码的关系

### 9.1 需要替换的文件

- `onboarding_screen.dart` → 拆成 4 个独立页面
- `onboarding_notifier.dart` → 替换为 `OnboardingSessionNotifier` + 页面本地状态
- `onboarding_view_model.dart` → 删除（Riverpod 直接管理 notifier）

### 9.2 需要新增的文件

- `onboarding_name_screen.dart` — 名字输入页
- `onboarding_scene_screen.dart` — 场景选择页
- `onboarding_practice_screen.dart` — 练习页
- `onboarding_complete_screen.dart` — 结束态
- `onboarding_session_notifier.dart` — 跨页面共享状态
- `scene_phrase_service.dart` — 本地句库服务
- `practice_scene.dart` — 场景枚举与扩展
- `baby_reaction.dart` — 反应枚举
- `practice_record.dart` — 练习记录模型

### 9.3 复用的现有组件

- `AppScaleButton` — 按钮按压动画
- `AppSeedSprout` — 萌芽动画
- `AppHaptics` — 触觉反馈
- `AppMentorBubble` — 导师气泡
- `AppStepProgress` — 步骤进度条（名字页可选用）
- `AppBanner` — 提示横幅
- `AppLayoutConstants` — 布局常量

### 9.4 需要修改的文件

- `app_router.dart` / `app_go_router.dart` — 新增 4 条 onboarding 路由
- `repository_providers.dart` — 新增 `ScenePhraseService` provider
- `app_localizations.dart` — 新增 V21 相关文案

## 10. 完成流程

点击"先到这里"时：
1. 将 `OnboardingSession` 数据转换为 `OnboardingSnapshot`
2. 年龄可选：若用户未选年龄，使用默认值（根据场景推断合理默认，或使用 `zeroToSix` 作为 fallback）
3. 调用 `OnboardingRepository.completeOnboarding` 保存快照
4. 导航到首页（`context.go('/')`）

"再来一句"不触发完成流程，仅回到练习页继续练习。

## 11. 非目标

- 不恢复长聊天式 onboarding
- 不把第一句练习做成小课程或多步骤打卡
- 不在 onboarding 中展示拼音或英文转写
- 不在年龄选择后推断宝宝偏好、性格或能力
- 不在 onboarding 中接入后端 LLM 生成（使用本地句库）
