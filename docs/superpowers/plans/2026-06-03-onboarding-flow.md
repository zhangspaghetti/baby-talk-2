# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 6-step onboarding flow matching GPT designs with "experience first, information later" principle.

**Architecture:** Modify existing onboarding screens to match GPT visual style. Add new garden welcome screen. Update models for optional name and age selection.

**Tech Stack:** Flutter, Riverpod, GoRouter

---

## Task 1: Update PracticeScene Labels

**Files:**
- Modify: `mobile/lib/features/onboarding/domain/models/practice_scene.dart`

- [ ] **Step 1: Update scene labels to match GPT design**

```dart
String get label {
  switch (this) {
    case PracticeScene.feeding:
      return '吃饭时间';
    case PracticeScene.drinking:
      return '喝水时间';
    case PracticeScene.diaper:
      return '换尿布';
    case PracticeScene.bath:
      return '洗澡时间';
    case PracticeScene.bedtime:
      return '睡前时光';
    case PracticeScene.outing:
      return '出门时光';
  }
}
```

- [ ] **Step 2: Update scene emojis**

Add getter for emoji:

```dart
String get emoji {
  switch (this) {
    case PracticeScene.feeding:
      return '🍚';
    case PracticeScene.drinking:
      return '🥤';
    case PracticeScene.diaper:
      return '👶';
    case PracticeScene.bath:
      return '🛁';
    case PracticeScene.bedtime:
      return '🌙';
    case PracticeScene.outing:
      return '🚶';
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/onboarding/domain/models/practice_scene.dart
git commit -m "feat: update practice scene labels and emojis"
```

---

## Task 2: Update OnboardingSession Model

**Files:**
- Modify: `mobile/lib/features/onboarding/domain/models/onboarding_session.dart`

- [ ] **Step 1: Add age bucket enum if not exists**

Check if `OnboardingAgeBucket` exists. If not, add:

```dart
enum OnboardingAgeBucket {
  months0_6,
  months7_12,
  year1,
  year2,
  year3,
}

extension OnboardingAgeBucketX on OnboardingAgeBucket {
  String get label {
    switch (this) {
      case OnboardingAgeBucket.months0_6:
        return '0-6个月';
      case OnboardingAgeBucket.months7_12:
        return '7-12个月';
      case OnboardingAgeBucket.year1:
        return '1岁';
      case OnboardingAgeBucket.year2:
        return '2岁';
      case OnboardingAgeBucket.year3:
        return '3岁';
    }
  }
}
```

- [ ] **Step 2: Ensure childName is optional**

Verify `childName` field is `String?` (nullable). If not, make it optional.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/onboarding/domain/models/onboarding_session.dart
git commit -m "feat: ensure onboarding session supports optional name"
```

---

## Task 3: Restyle OnboardingSceneScreen

**Files:**
- Modify: `mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart`
- Modify: `mobile/lib/features/onboarding/presentation/widgets/scene_button.dart`

- [ ] **Step 1: Update SceneButton to card style**

Replace current SceneButton with 2x2 grid card:

```dart
class SceneButton extends StatelessWidget {
  const SceneButton({
    super.key,
    required this.scene,
    required this.isSelected,
    required this.onTap,
  });

  final PracticeScene scene;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentSoft : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.accent : colors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              scene.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              scene.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update OnboardingSceneScreen layout**

Restructure to match GPT design:
- Add mentor avatar at top
- Add title and subtitle
- Use 2x2 grid for scene buttons
- Add helper text
- Update CTA button text

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_scene_screen.dart
git add mobile/lib/features/onboarding/presentation/widgets/scene_button.dart
git commit -m "feat: restyle onboarding scene screen to match GPT design"
```

---

## Task 4: Update OnboardingPracticeScreen

**Files:**
- Modify: `mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart`

- [ ] **Step 1: Add progress indicator**

Add "1 / 4" progress text and optional progress bar.

- [ ] **Step 2: Update phrase display layout**

Match GPT design:
- Large English text (centered)
- Chinese translation below
- Phonetic in brackets
- Audio button

- [ ] **Step 3: Add "我说了" CTA button**

Orange button with heart icon and sparkle text.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_practice_screen.dart
git commit -m "feat: update practice screen to match GPT design"
```

---

## Task 5: Add Baby Reaction Options

**Files:**
- Modify: `mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart`

- [ ] **Step 1: Update reaction icons to match GPT**

```dart
// 开心回应 😊
// 玩水了 🍼  
// 没反应也没关系 😐
```

- [ ] **Step 2: Update reaction button layout**

Horizontal row of 3 reaction options.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/widgets/reaction_button.dart
git commit -m "feat: update reaction buttons to match GPT design"
```

---

## Task 6: Update OnboardingCompleteScreen

**Files:**
- Modify: `mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart`

- [ ] **Step 1: Add sprout animation**

Use existing `AppSeedSprout` widget or create new animation.

- [ ] **Step 2: Update copy to match GPT**

```
Title: "你刚刚和宝宝分享了第一组英语 🌱"
Subtitle: "一颗小种子已经种下，持续的表达会让它慢慢成长。"
```

- [ ] **Step 3: Update CTA button**

```
"看看我的花园" (orange button)
"稍后再说" (skip link)
```

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_complete_screen.dart
git commit -m "feat: update complete screen with sprout animation"
```

---

## Task 7: Update OnboardingNameScreen

**Files:**
- Modify: `mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart`

- [ ] **Step 1: Make name input optional**

Change label to "宝宝昵称（可选）" and placeholder to "比如：小宝、小明..."

- [ ] **Step 2: Add age selection**

Add radio button group for age buckets:
- 0-6个月 🌱
- 7-12个月 🌿
- 1岁 🌳
- 2岁 🌳
- 3岁 🌳

- [ ] **Step 3: Add mentor bubble**

```
"小禾想帮你记录这段珍贵的成长，可以告诉我一些关于宝宝的小信息吗？"
```

- [ ] **Step 4: Add skip option**

"稍后再说" link at top right and bottom.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_name_screen.dart
git commit -m "feat: add age selection and make name optional"
```

---

## Task 8: Create Garden Welcome Screen

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/screens/onboarding_garden_welcome_screen.dart`

- [ ] **Step 1: Create new screen**

```dart
class OnboardingGardenWelcomeScreen extends ConsumerWidget {
  const OnboardingGardenWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(onboardingSessionProvider).session;
    final childName = session.childName ?? '你的';
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Garden illustration
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/garden/garden_welcome.png',
                  width: 200,
                  height: 200,
                ),
              ),
            ),
            
            // Welcome text
            Text(
              '欢迎来到${childName}的花园 🌼',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '我们会一起，慢慢记录每一个你们的温暖时刻。',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            
            // CTA button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('开始我们的花园之旅'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('去首页看看'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add route to GoRouter**

Update router configuration to include new screen.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/onboarding/presentation/screens/onboarding_garden_welcome_screen.dart
git commit -m "feat: create garden welcome screen"
```

---

## Task 9: Update Navigation Flow

**Files:**
- Modify: `mobile/lib/app/router/app_go_router.dart`

- [ ] **Step 1: Update onboarding routes**

Ensure flow is:
1. `/onboarding/scene` → Step 1
2. `/onboarding/practice` → Step 2-3
3. `/onboarding/complete` → Step 4 (sprout animation)
4. `/onboarding/name` → Step 5 (optional info)
5. `/onboarding/garden-welcome` → Step 6 (final)

- [ ] **Step 2: Update navigation logic**

After Step 4 (sprout), navigate to Step 5 (name). After Step 5, navigate to Step 6 (garden welcome).

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/app/router/app_go_router.dart
git commit -m "feat: update onboarding navigation flow"
```

---

## Task 10: Visual Verification

- [ ] **Step 1: Run app and test onboarding flow**

```bash
cd mobile && flutter run
```

- [ ] **Step 2: Verify each screen matches GPT design**

Compare with reference image `ChatGPT Image 2026年6月3日 18_09_56.png`

- [ ] **Step 3: Test skip flows**

- Skip name input → should use "宝宝" throughout
- Skip garden welcome → should go to home

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete onboarding flow redesign"
```

---

## Summary

| Task | Description | Files Changed |
|------|-------------|---------------|
| 1 | Update scene labels | `practice_scene.dart` |
| 2 | Update session model | `onboarding_session.dart` |
| 3 | Restyle scene screen | `onboarding_scene_screen.dart`, `scene_button.dart` |
| 4 | Update practice screen | `onboarding_practice_screen.dart` |
| 5 | Add reaction options | `reaction_button.dart` |
| 6 | Update complete screen | `onboarding_complete_screen.dart` |
| 7 | Update name screen | `onboarding_name_screen.dart` |
| 8 | Create garden welcome | `onboarding_garden_welcome_screen.dart` |
| 9 | Update navigation | `app_go_router.dart` |
| 10 | Visual verification | None |

**Total estimated time:** 2-3 hours
