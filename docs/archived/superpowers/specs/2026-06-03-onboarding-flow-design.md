# Onboarding Flow Design Spec

**Date:** 2026-06-03
**Status:** Approved
**Scope:** Sub-project 2 of 10 (UI Iteration)
**Reference:** `ChatGPT Image 2026年6月3日 18_09_56.png`

## Overview

Redesign the onboarding flow to follow "experience first, information later" principle. Users practice English phrases before being asked for baby information. Name is optional throughout.

## Design Principles

1. **Give value first** — Users practice phrases before entering any personal data
2. **Name is optional** — Use "宝宝" / "小宝贝" until user provides a name
3. **Emotional reward** — Seed sprout animation after first practice
4. **Apple-style** — Clean, minimal, no forms until value is delivered

## 6-Step Flow

### Step 1/6: Welcome Page

**Purpose:** Let user select a scene and start practicing immediately.

**Layout:**
- Mentor avatar (小禾老师) with subtitle "你的英语育儿伙伴"
- Title: "今晚想和宝宝说些什么呢？"
- Subtitle: "不需要学英语，只需要和宝宝说几句话。"
- 4 scene cards in 2x2 grid:
  - 睡前时光 🌙
  - 吃饭时间 🍚
  - 洗澡时间 🛁
  - 换尿布 👶
- Helper text: "不知道说什么？点下面按钮，小禾给你几句话"
- CTA: "给我几句话" (orange button)

**Navigation:** Tap scene → Step 2

**Data:** No personal data needed

---

### Step 2/6: First Phrase

**Purpose:** Show first phrase for selected scene.

**Layout:**
- Back button (top left)
- Mentor bubble: "太棒了！{scene}是和宝宝亲密交流的好时机。"
- Scene tag: "{scene} 🛁"
- Phrase display (large, centered):
  - English: "I love bath time with you."
  - Chinese: "我喜欢和你一起洗澡。"
  - Phonetic: "[ aɪ lʌv bæθ taɪm wɪð ju ]"
  - Audio button
- Progress: "1 / 4"
- CTA: "我说了 ✨" (orange button with heart icon)
- Helper: "等你说完再点哦 →"

**Navigation:** Tap "我说了" → Step 3

**Data:** Record practice event

---

### Step 3/6: Continue Practice

**Purpose:** Show next phrases with baby reaction tracking.

**Layout:**
- Progress bar (2/4)
- Mentor encouragement: "你说得真好，宝宝一定感受到了你的爱 💛"
- Phrase display (same format as Step 2)
- Baby reaction options (3 buttons):
  - 开心回应 😊
  - 玩水了 🍼
  - 没反应也没关系 😐
- CTA: "我说了 ✨"

**Navigation:** Complete 4 phrases → Step 4

**Data:** Record practice events + reactions

---

### Step 4/6: Seed Sprout Animation

**Purpose:** Emotional reward for completing first practice.

**Layout:**
- Sprout illustration (animated, growing from seed)
- Title: "你刚刚和宝宝分享了第一组英语 🌱"
- Subtitle: "一颗小种子已经种下，持续的表达会让它慢慢成长。"
- CTA: "看看我的花园" (orange button)
- Skip: "稍后再说"

**Navigation:** Tap CTA → Step 5, Tap skip → Step 6

**Data:** None

---

### Step 5/6: Baby Info (Optional)

**Purpose:** Collect baby name and age for personalization.

**Layout:**
- Skip: "稍后再说" (top right)
- Mentor bubble: "小禾想帮你记录这段珍贵的成长，可以告诉我一些关于宝宝的小信息吗？"
- Baby nickname input:
  - Label: "宝宝昵称（可选）"
  - Placeholder: "比如：小宝、小明..."
  - Optional leaf decoration
- Baby age selection (radio buttons):
  - 0-6个月 🌱
  - 7-12个月 🌿
  - 1岁 🌳
  - 2岁 🌳
  - 3岁 🌳
- CTA: "保存" (orange button)
- Skip: "稍后再说"

**Navigation:** Tap save/skip → Step 6

**Data:** Baby name (optional), age (optional)

---

### Step 6/6: Garden Welcome

**Purpose:** Welcome user to their garden, transition to main app.

**Layout:**
- Garden illustration with flowers and sign
- Sign text: "{baby_name}的花园" (or "你的花园" if no name)
- Title: "欢迎来到{baby_name}的花园 🌼" (or "欢迎来到你的花园")
- Subtitle: "我们会一起，慢慢记录每一个你们的温暖时刻。"
- CTA: "开始我们的花园之旅" (orange button)
- Skip: "去首页看看"

**Navigation:** Tap CTA/skip → Home screen

**Data:** None

---

## Existing Code Mapping

| GPT Step | Existing Screen | Changes Needed |
|----------|-----------------|----------------|
| Step 1 | `OnboardingSceneScreen` | Restyle to match GPT (2x2 grid, mentor avatar) |
| Step 2-3 | `OnboardingPracticeScreen` | Add progress indicator, reaction options |
| Step 4 | `OnboardingCompleteScreen` | Add sprout animation, update copy |
| Step 5 | `OnboardingNameScreen` | Add age selection, make name optional |
| Step 6 | New screen | Create garden welcome screen |

## Files to Modify

### Screens
- `onboarding_scene_screen.dart` — Restyle to 2x2 grid with mentor
- `onboarding_practice_screen.dart` — Add progress bar, reactions
- `onboarding_complete_screen.dart` — Add sprout animation
- `onboarding_name_screen.dart` — Add age selection, optional name
- `onboarding_garden_welcome_screen.dart` — **NEW** final welcome

### Widgets
- `scene_button.dart` — Update to card style with emoji
- `reaction_button.dart` — Update icons to match GPT
- `countdown_progress_bar.dart` — Update to match GPT style

### Models
- `onboarding_session.dart` — Add age bucket field
- `practice_scene.dart` — Update labels to match GPT

### Notifier
- `onboarding_session_notifier.dart` — Add age selection, step tracking

## Visual Style (from GPT)

- **Background:** Warm cream `#FFF8F0`
- **CTA buttons:** Orange `#FF8C42` with rounded corners
- **Text:** Warm dark `#2D2926`
- **Mentor avatar:** Xiaohe character illustration
- **Progress:** Orange bar on cream track
- **Cards:** White/cream with subtle shadows
- **Emojis:** Used as scene identifiers

## Success Criteria

- [ ] 6-step flow matches GPT design exactly
- [ ] Name is optional throughout (uses "宝宝" as fallback)
- [ ] Age selection added to Step 5
- [ ] Sprout animation in Step 4
- [ ] Garden welcome in Step 6
- [ ] All transitions smooth
- [ ] Data persists correctly
