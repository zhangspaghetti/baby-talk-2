# REFACTOR-042: Onboarding Product-Grade Redesign Plan

Status: proposed
Stage: Stage 3.0 design / planning
Owner: mobile UI/UX
Created: 2026-05-21
Depends on: Stage 3.1 Slice 2 onboarding preview/save-state UX

## Purpose

Turn onboarding from a contract-compliant setup flow into a product-grade activation flow for Chinese parents and caregivers of 0-3 year old children.

The current Slice 2 work made onboarding safer and more maintainable: preview copy is localized, save failure is accessible, preview spacing uses existing tokens, and local save behavior is preserved. This task is not another cleanup pass. It defines the next product experience target before implementation.

This plan preserves the Phase 1 core hypothesis: parents will say English phrases to their baby in daily care scenes and keep returning to do it again.

## Product Position

Onboarding should not feel like the app is demonstrating a personalization engine. It should help a parent get one sentence they can say in a real care moment.

This task supersedes only the registration portion of the 2026-04-04 `DESIGN.md` onboarding decision. It keeps the mentor role, age quick-pick, and 30-second mini-scene intent, but removes account registration from the onboarding activation contract until a later explicit consent or sync value boundary is approved.

Target anxiety:

- "My English is not good enough."
- "I do not know what to say to a baby."
- "I do not want to upload child data before I understand the app."
- "I have very little time and may be holding the baby with one hand."

Product promise:

- In 30-60 seconds, the parent gets one stage-fit English phrase they can say once immediately.
- The app explains when to say it and makes it okay if the baby does not respond.
- Before explicit consent, nickname, age bucket, stage, first phrase state, first practice action, and first seed state remain local to this device.

Activation definition:

- Preview activation: stage-fit first phrase is shown.
- Product activation: the parent plays or says the first phrase, marks the lightweight "I said it" action, local save succeeds, and the personalized home continues the same stage, first phrase, and first seed.
- Confirmed activation: the parent later starts or repeats practice from that personalized home and records a first baby response or reaction.
- Habit validation: a returning parent sees a clear daily phrase cue and can continue from the previous local state without rebuilding onboarding.

Do not count preview-only as full activation.

## Experience Principles

1. Start with permission, not data collection.
   - Good: "不用标准发音，先拿一句今天能说的。"
   - Avoid: "请先完成宝宝档案。"

2. Use care-scene language, not internal system terms.
   - Good: "先从洗澡时这句话开始。"
   - Avoid as primary copy: "starter seed", "阶段匹配", "个性化引擎".

3. Local-only is a complete safe mode.
   - Good: "先在本机为宝宝准备练习，不上传，也不需要精确生日。"
   - Avoid: "未登录", "游客模式", "资料未完成".

4. One screen, one decision.
   - Keep each step focused on one action: identify baby, choose age bucket, accept first phrase, start.

5. Preserve continuity after save.
   - The phrase shown in onboarding must remain the first actionable card on home.
   - No content reset after completion.

## Proposed Flow

### Step 1: Private First Start

Goal: reassure the parent and begin with minimal input.

Composition:

- Top: compact progress text, for example "第 1 步 / 共 3 步 · 约 30 秒".
- Header row: 小禾老师 identity plus local-only trust pill.
- Main mentor card: one warm promise, not a transcript.
- Composer: child nickname input and primary CTA.

Primary copy direction:

- Title: "先拿一句今天能说的英文"
- Body: "只用宝宝昵称和大概月龄，我会先在本机配好第一句。"
- Trust pill: "仅保存在本机"
- CTA: "继续选择月龄"

### Step 2: Age Bucket With Meaning

Goal: select age bucket while explaining what the choice affects.

Composition:

- A short mentor line: "不用精确生日，选最接近的一档就好。"
- Age bucket cards with stronger selected state.
- Selected-state preview line below the grid, for example "更适合短句轮流回应".
- Explicit primary CTA; do not auto-advance on selection.

Responsive rule:

- Default: current compact grid may remain.
- If text scale is high or width is narrow, degrade to 2 columns.

### Step 3: First Phrase Mini-Scene

Goal: preserve the original Phase 1 mini-scene: show a concrete phrase, let the parent try it once, and create the first local seed.

Composition:

- One action card, not separate system explanation cards.
- English phrase in the existing English display treatment.
- Chinese meaning.
- "When to say it" care-scene hint.
- "What if baby does not respond" reassurance.
- TTS play affordance.
- Primary lightweight action: "我说了" or equivalent.
- Optional baby response affordance after the parent action, if it does not add another required decision.
- Local save recap and save failure inline state.

Primary copy direction:

- Label: "第一句可以先这样说"
- Save recap: "确认后会先写入这台设备，方便下次直接继续。"
- CTA before action: "播放一下"
- CTA after action: "我说了"
- Completion CTA: "进入首页继续"
- Secondary: "返回调整"

Seed rule:

- Completing the lightweight phrase action creates the first local seed for the matched activity.
- This preserves the Phase 1 rule that the garden should not be empty after onboarding.
- The seed remains local before explicit consent or sync approval.

Save failure copy pattern:

- "未能写入本机档案；刚才的昵称和月龄档已保留，点击重试即可。"

Do not show raw storage exceptions in parent-facing copy.

### Step 4: Home Continuity

Goal: make completion feel valuable, not like a redirect.

Decision:

- Onboarding completion lands on the existing post-onboarding home destination.
- `mobile/lib/features/practice/presentation/screens/home_screen.dart` owns the first post-onboarding continuity surface unless implementation review finds a narrower existing home card owner.
- Practice starts from the home continuity CTA; REFACTOR-042 does not introduce a direct onboarding-to-practice route.
- No route behavior change is approved in this task.

Home must carry over:

- same child name,
- same stage summary,
- same first phrase,
- first local seed state,
- same next action.

The first post-onboarding home state should answer: "What do I say now?"

The second visit home state should answer: "What should I say today?"

Daily habit rule:

- REFACTOR-042 must leave the parent with a visible next daily phrase cue after onboarding.
- It may reuse the existing Smart Home recommendation surface; no new notification system is approved here.
- It must not make the first seed feel like a one-time demo artifact.

## Visual Direction

Use Warm Paper Kindness as-is.

Keep:

- warm paper background,
- restrained orange for primary actions,
- teal for English phrase and trust/seed surfaces,
- mentor bubble language,
- single-column mobile layout,
- existing `AppTheme` and `AppLayoutConstants`.

Avoid:

- hero marketing composition,
- decorative gradients or orbs,
- child-game visuals,
- typing animations,
- chat-delay performance,
- dense transcript replay on the first viewport.

Preferred first viewport structure:

```text
第 1 步 / 共 3 步 · 约 30 秒                 仅保存在本机

小禾老师
先拿一句今天能说的英文。
不用标准发音，也不用精确生日。

[ 宝宝昵称 input ]
[ CTA: 继续选择月龄 ]

完成后会看到：第一句英文 + 什么时候说 + 怎么接住宝宝反应
```

## Accessibility and State Rules

- All interactive targets remain at least 48dp.
- Primary CTA remains at least the existing button minimum height.
- Live region is reserved for save failure or other status changes that require announcement.
- Mentor content should avoid duplicate announcements while preserving trailing content semantics.
- Text scaling must be tested for nickname input, age cards, first phrase card, and save failure banner.
- The age selector should have a responsive fallback for high text scale or narrow width.
- Save failure must keep the user on the first phrase preview with all inputs retained.

## Trust and Consent Boundary

Before explicit consent:

- no server-side child profile creation,
- no nickname upload,
- no age or stage upload,
- no practice event upload,
- no family share eligibility,
- no cross-device restore.

Consent should be introduced later only at a real value boundary:

- restore on another device,
- invite another caregiver,
- back up progress,
- sync practice history.

Consent copy should enumerate the data classes that will begin syncing. Avoid vague privacy language.

## Future Implementation Slice

Suggested next implementation slice after approval:

Task name: Product-grade onboarding activation slice

Primary files:

- `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- `mobile/lib/features/onboarding/presentation/widgets/*`
- `mobile/lib/features/practice/presentation/screens/home_screen.dart`, only for the first post-onboarding continuity surface and without route changes
- garden/home seed display surface, only if the first local seed is not already visible from home
- `mobile/lib/l10n/app_zh.arb`
- focused onboarding/home widget tests

Allowed support:

- a feature-owned onboarding action card widget,
- responsive age-grid layout inside onboarding presentation,
- localized copy keys,
- tests for text scaling, save failure, and home continuity.

Not allowed in the same slice:

- account or consent implementation,
- backend API changes,
- deleting onboarding repository behavior,
- app router decomposition,
- new packages,
- analytics implementation before the event schema is approved.

Acceptance criteria:

- New user can reach the first actionable phrase in at most 4 key interactions and one text input.
- Parent-facing copy contains no primary-system terms such as "starter seed" or "阶段匹配".
- Local-only promise is visible but not the dominant visual element.
- First phrase preview includes English phrase, Chinese meaning, care-scene hint, and reassurance.
- First phrase mini-scene includes a TTS play affordance and a lightweight "I said it" action.
- Completing the first phrase action creates a local first seed so the garden is not empty after onboarding.
- Save failure answers what failed, what was retained, and what to do next.
- Home after onboarding carries the same stage, first phrase, and first seed state.
- Home presents a next daily phrase cue so the Phase 1 daily-use hypothesis remains testable.
- Text scale and narrow-width age selection have explicit widget coverage.
- No repository, route, account, or consent behavior changes are introduced.

## Future Analytics Schema

Do not implement analytics in this planning task. Proposed privacy-safe events:

- `onboarding_started`
- `onboarding_name_completed`
- `onboarding_age_bucket_selected`
- `onboarding_stage_preview_viewed`
- `onboarding_local_save_succeeded`
- `onboarding_activation_reached`
- `starter_phrase_practice_started_from_home`
- `starter_phrase_first_reaction_recorded`
- `daily_phrase_cue_viewed`
- `daily_phrase_practice_started`
- `onboarding_local_save_failed`
- `onboarding_local_save_retried`
- `consent_upgrade_entry_viewed`
- `consent_upgrade_accepted`
- `consent_upgrade_declined`

Pre-consent payloads must not include nickname, exact birthdate, or free-text fields. Allowed examples: `age_bucket`, `stage_id`, `phrase_id`, `local_only`, `retry_count`, and coarse session context.

## Open Questions

1. Should the product-grade implementation merge nickname and age bucket into one screen, or preserve the current step model for lower behavior risk?
2. Should there be an escape hatch after repeated local-save failures, such as "continue once without saving"?
3. When analytics are approved, where should pre-consent privacy-safe event boundaries be enforced?

## Verification Plan

Planning verification:

- Human review of this product direction.
- UI review against `DESIGN.md` Warm Paper Kindness constraints.
- Architecture review of any home-continuity file touch before implementation.

Implementation verification, if approved later:

- `dart analyze`
- focused onboarding widget tests
- focused home-continuity widget tests
- a11y semantics smoke tests
- hardcoded onboarding copy scan
- `bash ci/mobile-r4-release-gates.sh`