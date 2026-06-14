# Flutter Mobile Practice 页面 V21 实现设计

日期：2026-06-01  
状态：设计已确认，待实现计划

## 1. 背景

[基础规格](2026-05-26-flutter-mobile-practice-design.md)已于 2026-05-26 确认。本文档是在该规格基础上补充的**实现级设计**，明确代码结构、状态机、API 集成方式，供实现计划直接使用。

**当前代码 vs 规格的主要差距：**

| 规格要求 | 当前实现 | 状态 |
|---------|---------|------|
| 固定底部 `说完了` / `换一句` / `结束` 操作栏 | 无固定底部栏，反应在卡片内滚动 | ❌ 缺失 |
| `说完了` → 保存 → 展示宝宝反应（两步流程） | 选反应即保存，无先保存步骤 | ❌ 流程不符 |
| 场景特定反应选项 | 全局固定 3 个选项 | ❌ 不符 |
| 发音播放文案对齐规格 | 使用通用 AppAudioButton 文案 | ⚠️ 部分符合 |
| 结束态独立视图 | 仅展示 Banner 后 pop | ❌ 缺失 |
| 下一句加载状态 UI | 无专属 UI | ❌ 缺失 |

**范围决定：**
- 全面对齐基础规格的全部 10 节
- 在原有文件就地重构（不新建路由）
- 音频逻辑（flutter_tts / audioplayers）本期不动，仅更新 UI 文案
- `换一句` 功能接入已有 `/practice/generate` 后端端点

---

## 2. 架构方案

采用**方案 A：底部操作栏 + 卡片内联状态切换**。

```
PracticeSessionScreen
└── Scaffold
    ├── AppBar（透明，含场景副标题）
    ├── body: SafeArea > ConstrainedBox(maxWidth=640) > Column
    │   ├── [进度条行] LinearProgressIndicator + 进度文本
    │   ├── [滚动区 Expanded] SingleChildScrollView
    │   │   ├── AppMentorBubble（小禾轻提示，场景特定文案）
    │   │   ├── CoachTipExpansionTile（折叠态仅「提示」）
    │   │   └── 主卡片区 AnimatedSwitcher
    │   │       ├── PhraseCard[ready]   → 句卡 + 发音按钮
    │   │       ├── PhraseCard[saved]   → 句卡 + 「已保存本句」+ 场景反应芯片
    │   │       └── PracticeCompletionView → 结束态
    │   └── [固定] PracticeBottomActionBar
    │         ├── phase=ready    「说完了」FilledButton | 「换一句」「结束」TextButton
    │         ├── phase=loading  「下一句准备中」禁用按钮 + spinner
    │         └── phase=saved    「跳过，下一句」TextButton
```

---

## 3. 状态机设计

### 3.1 `PhraseInteractionPhase`

新增枚举控制单句生命周期：

```dart
enum PhraseInteractionPhase {
  ready,      // 初始态：底部「说完了/换一句/结束」
  saved,      // 已保存：底部「跳过，下一句」，卡片展示反应按钮
  advancing,  // 选反应后倒计时 1.35s 自动进下一句
  complete,   // 全部句子完成，显示结束态
}
```

### 3.2 `NextPhraseLoadStatus`

控制「换一句」/「下一句」的加载状态：

```dart
enum NextPhraseLoadStatus {
  idle,
  loading,  // 「下一句准备中」
  error,    // 「换一句没准备好，点我重试」
}
```

### 3.3 新增 Notifier 方法

| 方法 | 触发 | 说明 |
|------|------|------|
| `saveCurrentPhrase()` | 点击「说完了」 | 保存本句，phase → saved；原 recordReaction 流程改为先 save |
| `recordReaction(type)` | 选反应芯片 | 仅在 saved 阶段可调；记录反应后 phase → advancing，1.35s 后进下一句 |
| `skipToNextPhrase()` | 点击「跳过，下一句」 | 不记录反应，直接进下一句 |
| `skipCurrentPhrase()` | 点击「换一句」 | 调后端 generate API，替换当前句；nextPhraseLoadStatus → loading |
| `cancelAutoAdvance()` | 用户点击「换一句」/「结束」/返回 | 取消 1.35s Timer，阻止自动跳转 |
| `endSession()` | 点击「结束」 | phase → complete |

---

## 4. UI 组件变更

### 4.1 `practice_session_screen.dart`（就地重构）

**AppBar 变化：**
- `title`: 固定为 `今日一句`
- 新增 `bottom: PreferredSize` 显示场景副标题（如 `喂饭 / 一句就够`）
- 进度条从 ListView 移到 body 顶部固定区域

**body 变化：**
- 原 `ListView` → `Column(children: [进度区, Expanded(SingleChildScrollView(...)), PracticeBottomActionBar])`
- `AnimatedSwitcher` 包裹主卡片区，key 在 `phase == complete` 时切换

### 4.2 `phrase_card.dart`（修改）

- 新增 `PhraseCardPhase` 参数（`ready` / `saved`）
- `ready` 态：保留英文、中文、发音按钮；**移除** ReactionChipRow
- `saved` 态：新增 `已保存本句` 绿色标签 + `SceneReactionChipRow`（接收 `sceneTag`）
- 发音按钮文案更新（见第 5 节）

### 4.3 `reaction_chip_row.dart`（修改）

- 重命名为 `scene_reaction_chip_row.dart`
- 接收 `sceneTag` 参数，根据场景返回特定选项（见第 6 节）
- 新增选中态 UI：选中后显示 checkmark 图标 + `semanticsSelected: true`（不再只依赖颜色）

### 4.4 `PracticeBottomActionBar`（新建）

文件：`widgets/practice_bottom_action_bar.dart`

```dart
class PracticeBottomActionBar extends StatelessWidget {
  const PracticeBottomActionBar({
    required this.phase,
    required this.nextLoadStatus,
    required this.onSave,
    required this.onSkipPhrase,   // 换一句
    required this.onEnd,
    required this.onSkipReaction, // 跳过，下一句
    required this.onRetryNextPhrase,
  });
  // ...
}
```

布局规则：
- `说完了` 按钮宽度全宽，高度 48px，`FilledButton`
- 次级按钮 `TextButton`，高度 ≥ 44px
- `loading` 态：主区域显示 `下一句准备中` + `CircularProgressIndicator.adaptive()`，加上说明文案
- `error` 态：`换一句没准备好，点我重试` + 重试和结束两个入口

### 4.5 `PracticeCompletionView`（新建）

文件：`widgets/practice_completion_view.dart`

结构（参照规格第 8 节）：
```
Column
├── Text「今天完成了」（displaySmall）
├── AppMentorBubble「今天这样就很好。」
├── Text「你说出了 N 句。下次打开，小禾会继续给你一句。」
├── FilledButton「再来一句」→ 重置 session，phase = ready
└── TextButton「回到场景」→ Navigator.pop()
```

---

## 5. 发音播放文案

更新 ARB 文案字符串，音频逻辑**不改**：

| 状态 | 规格文案（按钮/文本） | ARB key |
|------|---------|---------|
| `idle` | `听小禾读` | `phrasePlaybackReady` |
| `playing` | `播放中` | `phrasePlaybackPlaying` |
| `completed` | `再听一次` | `phrasePlaybackCompleted` |
| `error` | `这句没读出来，点我重试` | `phrasePlaybackRetry` |

「准备中」用 `playing` 状态的 loading indicator 过渡，不新增 enum 值。

---

## 6. 场景特定反应选项

新增工具函数 `sceneReactionOptions(String? sceneTag)` 替换全局 `practiceReactionOptions`：

```dart
List<PracticeReactionOption> sceneReactionOptions(String? sceneTag) {
  switch (sceneTag) {
    case 'feeding':   return [engaged「有回应」, calm「吃了一口」, imitated「没反应」];
    case 'drinking':  return [engaged「有回应」, calm「喝了一口」, imitated「没反应」];
    case 'diaper':    return [engaged「有回应」, calm「配合了」,   imitated「没反应」];
    case 'bath':      return [engaged「有回应」, calm「配合了」,   imitated「没反应」];
    case 'bedtime':   return [engaged「有回应」, calm「安静了」,   imitated「没反应」];
    case 'going_out': return [engaged「有回应」, calm「配合了」,   imitated「没反应」];
    default:          return [engaged「有回应」, calm「认真听了」, imitated「没反应」];
  }
}
```

`BabyReactionType` 枚举不新增值，三类映射关系固定：
- `engaged` → 第一选项（总是「有回应」）
- `calm` → 第二选项（场景特定动作词）
- `imitated` → 第三选项（总是「没反应」）

---

## 7. 换一句 API 集成

**实际 API：** 现有 `DynamicPracticeApiService.generatePractice()` 调用  
`POST /api/v1/mentor/practice/generate`，请求体：

```json
{
  "installationId": "<device-id>",
  "surface": "practice",
  "babyAgeMonths": 12,
  "sceneTag": "feeding"
}
```

返回 `DynamicPracticeResponse { activities: [{ title, summary, sceneTag, coachTip, phrases: [...] }] }`

**调用链：**
```
PracticeSessionNotifier.skipCurrentPhrase()
  → nextPhraseLoadStatus = loading
  → DynamicPracticeApiService.generatePractice(installationId, babyAgeMonths, sceneTag)
  → 从 response.activities.first.phrases 中取第一条与当前 phraseId 不同的短语（客户端去重）
  → 成功：替换当前句，phase = ready，nextPhraseLoadStatus = idle
  → 失败：nextPhraseLoadStatus = error，sessionErrorMessage = 「换一句没准备好，点我重试」
```

**客户端去重策略：** API 不支持 `excludePhraseIds`，客户端遍历 response phrases，跳过与当前英文文本相同的结果；若全部相同则取 index 0（极端情况）。

**取消策略：** `skipCurrentPhrase()` 使用 Dio `CancelToken`；若用户在加载期间点击「结束」，调 `cancelToken.cancel()` 并 phase → complete。

---

## 8. 可访问性

| 要求 | 实现 |
|------|------|
| 所有按钮触控目标 ≥ 44px | 底部栏 `minHeight: AppLayoutConstants.minTouchTarget` |
| 选中反应不只依赖颜色 | 选中态加 checkmark 图标 + `Semantics(selected: true)` |
| TalkBack/VoiceOver | 保留现有 `Semantics` 标签；底部栏新增语义角色 |
| `prefers-reduced-motion` | `MediaQuery.disableAnimationsOf` 检查；动画效果减弱，1.35s 延迟保留 |
| 小屏防横向滚动 | `ConstrainedBox(maxWidth=640)` + 底部栏 `SafeArea` padding |

---

## 9. 测试覆盖

### 9.1 Widget 测试

- `PracticeBottomActionBar`：ready/saved/loading/error 四态快照
- `SceneReactionChipRow`：各场景选项文案正确，选中态语义
- `PracticeCompletionView`：N 句统计正确显示

### 9.2 Notifier 单元测试

- `saveCurrentPhrase()` → phase 从 ready → saved
- `recordReaction()` 在 saved 阶段正常记录 → advancing
- `skipToNextPhrase()` 跳过反应直接进下一句
- `skipCurrentPhrase()` 加载/失败/取消三种路径
- `cancelAutoAdvance()` 在 advancing 阶段取消 Timer

### 9.3 集成测试（可选，后续迭代）

- 完整练习流程：说完了 → 选反应 → 自动进下一句 → 完成 → 结束态

---

## 10. 不在范围内

- 后端 TTS API 接入（单独任务）
- 进度条样式改版（现有已符合基本要求）
- Garden 成长痕迹联动（已有 `GardenGrowthNotifier`，本期不改）
- `/practice/complete` 新路由（采用 in-place 方案，不新建路由）
