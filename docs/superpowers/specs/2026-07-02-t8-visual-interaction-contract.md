# T8.0 Visual Interaction Contract

Date: 2026-07-02
Status: Revised draft for user review
Scope: visual interaction contract only. No Flutter code, no backend code, no `mobile_v2`, no tests, no commit.
Plan source: `docs/superpowers/plans/2026-07-02-t8-duolingo-like-onboarding-redesign-plan.md`

## 1. Design Intent

T8.0 defines how Baby Talk should translate Duolingo-like onboarding into a parent-facing care moment flow. The correction from the first draft is important:

```text
禁止课堂化。
允许激励化。
禁止惩罚和比较焦虑。
允许正向成长反馈。
先给 first value，再引导注册保存。
```

Baby Talk is not a course app, but it should not be afraid of motivation. The first-run flow should borrow Duolingo's onboarding mechanics: complete the first core experience, deliver a light success beat, then ask the user to save progress with phone/account capture. Phone capture is post-value. It must never be a pre-value gate.

Locked T8 path:

```text
welcome
-> age
-> scene
-> goal
-> moment
-> first utterance
-> listen
-> said
-> baby reaction
-> next support
-> garden trace
-> save trace / phone capture
-> Today
```

What makes it Duolingo-like:
- One screen asks one thing.
- Progress and CTA rhythm make the path obvious.
- A memorable mascot accompanies the flow.
- Options give immediate feedback.
- The user receives a small success beat after doing the core action.
- Registration/save-progress appears after first value, not before.

What makes it Baby Talk:
- The core unit is a real care-turn, not a lesson.
- The mascot is original: 小水獭 TaTa.
- The success beat is a care trace, not correctness.
- Engagement terms become family-care growth metaphors, not school or test mechanics.

## 2. Duolingo Borrow / Adapt / Reject Matrix

### Borrow Directly As Interaction Principle

```text
one-screen-one-question
top progress
large tappable options
strong bottom CTA
selected-state feedback
guide/mascot companionship
micro success feedback
completion beat
post-value phone/account capture
motivating loop
```

These are interaction mechanics, not brand assets. Baby Talk should use them to make onboarding feel guided, fast, and emotionally rewarding.

### Adapt For Baby Talk

| Duolingo mechanic | Baby Talk translation | T8 placement |
| --- | --- | --- |
| XP | `亲子英语能量` / `照护英语能量` | Not a main T8 panel; may be lightly hinted after trace or in Today handoff. |
| coins/gems | `小贝壳` / `阳光` / `花园能量` | TaTa may carry a shell; complex economy deferred. |
| streak | `连续照护痕迹` / `最近常说` | Trace can imply the first continuity mark; no day-count pressure. |
| leaderboard | `好友家庭进度` / `家庭圈互相鼓励` | T9/T10 future layer; not first-run mainline. |
| score | `家庭启蒙指数` / `亲子英语成长反馈` | Future family-level reflection; not onboarding scoring. |
| mascot | `小水獭 TaTa` | Primary onboarding guide and emotional feedback. |
| course path | `今天照护小路` | Today care path, not curriculum. |
| completion | `第一条照护痕迹` / first care-turn success beat | Trace screen and shell glow. |
| account capture | `保存第一条照护痕迹的手机号注册` | Post-value screen after trace. |

### Reject

```text
Duolingo brand
owl / bird mascot silhouette
copied screenshots or recordings
exact UI copy
classroom exercises
right/wrong grading
pronunciation score as onboarding gate
child-performance ranking
shame-based streak pressure
competitive public leaderboard in first-run onboarding
course/lesson framing
```

Rejecting these does not mean rejecting motivation. It means motivation must support real family care, not classroom pressure.

## 3. TaTa Mascot Contract

The mascot is locked as:

```text
名字：小水獭 TaTa
角色：Baby Talk 照护英语陪伴员
性格：萌、鼓励、反应快、不评判
外形：圆脸、小耳朵、短手、抱一个小贝壳
主色：暖棕 + 奶油白 + 青绿色围巾
辅助物：小贝壳 / 小水滴 / 小芽
```

TaTa is:
- A memorable original animal mascot.
- Emotionally expressive like Duolingo's owl in function, but not in form.
- A companion who guides and reacts.
- The carrier of shell/trace motivation.

TaTa is not:
- A teacher.
- An English tutor.
- The baby.
- A Duolingo owl.
- A bird or owl silhouette.
- A generic parent-child illustration.

小芽 remains a Garden/trace growth symbol. It is no longer the mascot.

### TaTa In Onboarding

| Step | TaTa behavior |
| --- | --- |
| Welcome | TaTa appears and invites the parent to begin. |
| Age / Scene / Goal / Moment | TaTa asks one question in the guide bubble. |
| Option selected | TaTa nods, blinks, or the small shell glows. |
| First utterance | TaTa draws attention to the sentence. |
| Listen | TaTa takes a listening pose. |
| Said | TaTa gently encourages without judging pronunciation. |
| Reaction | TaTa says `选一个最接近的就好`. |
| Next support | TaTa offers the next support line. |
| Trace | TaTa raises the small shell to mark the first trace. |
| Phone capture | TaTa says `把这条痕迹保存下来吧`. |
| Today | TaTa moves to a small corner presence and does not dominate the main surface. |

### TaTa Asset Rules

- The four otter reference sheets under `docs/superpowers/specs/assets/mascot/` are concept references for TaTa's identity.
- `t8-mascot-tata-style-sheet.png` is the canonical T8.0 mascot style reference.
- Do not crop concept PNGs into production app assets.
- Future production assets should preserve the selected otter's round face, warm brown fur, cream face/belly, glossy eyes, teal scarf, shell pouch, short limbs, and soft 小红书-style warmth.
- Any newly generated TaTa image must be checked against the selected otter sheet before acceptance.

## 4. Screen-By-Screen Contract

Progress model:
- Welcome does not count as a committed data step.
- B-K are the 10 onboarding progress steps.
- L is a post-value save-progress screen. It may show a full progress bar or a separate save-step indicator, but must not imply course progress.
- M Today is outside onboarding progress.

### A. Welcome / Brand Moment

Purpose: introduce Baby Talk and TaTa, and make the first value feel one tap away.

Visible copy:

```text
Baby Talk
先拿一句现在能说的话
不用学英语，只要和宝宝轻轻说一句。
先拿第一句
```

Layout:
- Warm paper full-screen shell.
- TaTa is the hero, not a parent-child generic illustration.
- TaTa may wave and hold the shell pouch.
- No phone/account/login prompt.
- Bottom CTA pinned above safe area.

Progress: not counted. Optional hairline may show start state without numbers.

Feedback: CTA tap gives haptic/light scale feedback. TaTa can blink or shell can softly glint.

Transition: 220-280ms fade/slide into B.

### B. Baby Age Question

Purpose: capture rough age without becoming a profile form.

Visible copy:

```text
宝宝现在大概多大？
0-3个月
4-6个月
7-12个月
13-18个月
19-36个月
继续
```

Layout:
- Fixed top progress bar: step 1/10.
- TaTa appears in guide bubble.
- Single-column option cards preferred.
- CTA disabled until one option is selected.

Behavior:
- Option selection does not auto-advance.
- CTA commits the answer.
- Selected state uses soft teal surface/border, check mark, and TaTa nod/shell glow.

### C. Common Care Scene Question

Purpose: identify the broad care scene.

Visible copy:

```text
今天最常遇到哪个照护场景？
洗澡
喂奶
换尿布
穿鞋
睡前
继续
```

Layout:
- Step 2/10.
- Large cards with native text and simple scene icons.
- TaTa asks one short question.

Behavior:
- Select only, then CTA commit.
- Feedback strip can say `选一个今天最像的照护时刻。`

### D. Parent Goal Question

Purpose: understand what kind of help the parent wants today.

Visible copy:

```text
你今天最想要哪种帮助？
开口更自然
发音有信心
哄娃更顺
照护时能接上话
继续
```

Layout:
- Step 3/10.
- Text-forward goal cards.
- No English-level scale, quiz, or correctness framing.

Behavior:
- Selection enables CTA.
- TaTa gives a brief encouragement matched to the selected goal.

### E. Current Care Moment Question

Purpose: convert the broad scene into a concrete moment mapped to real content.

Visible copy, bath example:

```text
现在最像哪一刻？
准备碰水前
正在洗澡
要洗头前
准备擦干
快结束了
给我第一句
```

Layout:
- Step 4/10.
- Moment cards are concrete and action-bound.
- No English phrase appears yet.

Behavior:
- CTA starts the scoped onboarding care-turn setup.
- Selected moment must map to validated seed content or a safe fallback.

### F. First Utterance

Purpose: deliver the first real care-turn value.

Visible copy:

```text
这一句可以现在说
I love bath time with you.
我喜欢和你一起洗澡。
什么时候说
抱宝宝进浴室、准备碰水前说
听一下
```

Layout:
- Step 5/10.
- TaTa points attention to the utterance card.
- English phrase is the largest text.
- Audio control uses speaker/play only.

Behavior:
- `听一下` starts audio/TTS or fallback.
- `听一下` does not write an event.
- If audio fails, phrase remains visible and the parent can continue.

### G. Listen State

Purpose: keep the phrase stable while the parent hears it.

Visible copy:

```text
这一句可以现在说
I love bath time with you.
我喜欢和你一起洗澡。
正在听
已听过一次
我说了
```

Layout:
- Step 6/10.
- Same phrase card as F.
- TaTa uses the listening pose.

Behavior:
- Listening does not save an event.
- `我说了` opens H, not I.
- No microphone, recording, score, or pronunciation gate.

### H. Said State

Purpose: create a tiny post-say encouragement beat before asking about the baby.

Visible copy:

```text
已经说给宝宝听了
不用完美，刚才这一句已经开始了。
看看宝宝刚才的反应
```

Layout:
- Step 7/10.
- TaTa gently encourages, shell may lightly glow.
- This state can be brief or merged visually with the reaction prompt if implementation needs fewer screens, but the interaction contract remains: `我说了` does not save reaction.

Behavior:
- No event write.
- CTA or automatic 300-600ms transition opens reaction choices.
- No pronunciation judgment.

### I. Baby Reaction

Purpose: capture canonical reaction as care context, not score.

Visible copy:

```text
宝宝刚才是什么反应？
选一个最接近的就好
配合
犹豫
不想
没反应
其他
记录反应
```

Layout:
- Step 8/10.
- Reaction choices are accessible chips/cards.
- Visible labels are Chinese only.

Canonical mapping:

| Visible label | Internal value |
| --- | --- |
| `配合` | `BabyReactionType.cooperating` |
| `犹豫` | `BabyReactionType.hesitant` |
| `不想` | `BabyReactionType.resisting` |
| `没反应` | `BabyReactionType.noResponse` |
| `其他` | `BabyReactionType.other` |

Behavior:
- Selecting a reaction can select-only, then `记录反应` commits.
- Reaction save is the first persisted care-turn write.
- Save must pass through `care_path`, `CarePathNotifier`, `CarePathRepository.recordReaction()`, and `PracticeRepository.recordReaction()`.
- Double taps must not duplicate the event.

### J. Next Support

Purpose: prove Baby Talk reacts to the care moment and baby signal.

Visible copy:

```text
下一句可以这样接住
接着刚才的洗澡时刻
Warm water feels nice.
温温的水很舒服。
留下第一条痕迹
```

Layout:
- Step 9/10.
- TaTa offers support rather than celebration.
- The utterance card remains the visual center.

Behavior:
- Appears only after reaction save succeeds or enters a safe queued-local state.
- `留下第一条痕迹` does not create a second reaction event.

### K. Garden Trace / Mini Success

Purpose: show the first care trace and create the light success beat.

Visible copy:

```text
今天已经留下第一条照护痕迹
洗澡时刻
I love bath time with you.
进入保存
```

Layout:
- Step 10/10.
- TaTa raises the shell; the shell may glow once.
- 小芽 can appear as a tiny trace symbol.
- This is not a full Garden/Growth visual refactor.

Behavior:
- The success beat is allowed to feel rewarding.
- It may lightly imply `今天的亲子英语能量开始了` or `第一条连续照护痕迹开始了`.
- It must not show complex XP, shop, leaderboard, score panel, or public comparison.

Next transition: moves to L, the post-value save-progress screen.

### L. Save Trace / Phone Capture

Purpose: mimic Duolingo's post-value registration pattern. The parent has completed the first Baby Talk care-turn; now Baby Talk asks to save the first trace.

Visible copy:

```text
把第一条照护痕迹保存下来
换手机也能找回今天说过的第一句。
输入手机号
保存并进入今天
稍后再说
```

Layout:
- Post-value save screen, not a cold login form.
- TaTa appears as guide and says `把这条痕迹保存下来吧`.
- Include a small trace strip with scene and utterance if space allows.
- One phone input field.
- Primary CTA: `保存并进入今天`.
- Secondary CTA: `稍后再说`.

Behavior:
- Phone/account capture must not appear before first value.
- It must not block the user from first utterance, listen, said, reaction, next support, and trace.
- If backend account capability is not ready, this remains local-first visual/interaction contract. Later implementation may decide whether to connect existing account/phone capability.
- `稍后再说` enters Today and preserves local-first continuity.
- `保存并进入今天` should save or queue the account capture according to available implementation capability, then enter Today.

Progress:
- May show a full onboarding bar or a separate save indicator.
- Must not call it course progress.

### M. Today Handoff Preview

Purpose: confirm continuity after onboarding and save prompt.

Visible copy:

```text
今天
洗澡时刻
刚才留下的第一句还在这里
I love bath time with you.
继续接住这一刻
```

Layout:
- Today tab, not a dashboard.
- Current care moment remains dominant.
- Trace continuity appears near the top.
- Bottom nav may show `今天 / 场景 / 花园 / 我的`.
- TaTa is small, corner-level, and does not dominate.

Behavior:
- Today reads continuity from the real local event path.
- It is not an onboarding summary screen.

## 5. Image Gen Concept Inventory

All concept images below are original Baby Talk / TaTa concept assets or user-provided original TaTa references for this T8.0 contract. They are reference images only; do not crop them into production Flutter assets.

Base folder:

`docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/`

### A. Active T8.0 Source-Of-Truth Concept Assets

These assets are the current T8.0 visual source of truth. Later implementation should prioritize these over the earlier storyboard images.

| Image | Path | Covers | Must preserve | Mood only / do not hard-code |
| --- | --- | --- | --- | --- |
| TaTa style sheet | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-mascot-tata-style-sheet.png` | Canonical mascot reference | Warm-brown otter, cream face/belly, teal scarf, shell pouch, short limbs, soft healing style | Concept sheet labels and decorative plants only |
| TaTa welcome guide | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-mascot-tata-welcome-guide.png` | Welcome / guide bubble | TaTa as the onboarding entrance guide | Standalone concept, not production cutout |
| TaTa listening | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-mascot-tata-listening.png` | Listen / reaction prompt | TaTa listening pose, no microphone, no judgment | Standalone concept, not production cutout |
| TaTa success shell | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-mascot-tata-success-shell.png` | Trace / success beat / save handoff | Shell glow as the first trace success beat | Glow/pose are mood, not required animation asset |
| Phone capture after trace | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-phone-capture-after-trace.png` | L Save Trace / Phone Capture | Warm post-value save-progress screen with TaTa, phone input, and trace context | Image text quirks are non-authoritative; exact copy is this document |
| Motivation layer preview | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-motivation-layer-preview.png` | T9/T10 engagement layer preview | Light preview of `亲子英语能量`, `小贝壳`, and `连续照护痕迹` | Not a T8 main-flow implementation requirement |
| Mascot reference sheet 1 | `docs/superpowers/specs/assets/mascot/吉祥物形象约定图1.png` | TaTa role consistency | Canonical otter identity, rotations, expressions, palette | Decorative layout and labels only |
| Mascot reference sheet 2 | `docs/superpowers/specs/assets/mascot/吉祥物形象约定图2.png` | TaTa role consistency | Front/back/side proportions, scarf, shell pouch | Decorative layout and labels only |
| Mascot reference sheet 3 | `docs/superpowers/specs/assets/mascot/吉祥物形象约定图3.png` | TaTa role consistency | Shell-holding gesture and expressive poses | Decorative layout and labels only |
| Mascot reference sheet 4 | `docs/superpowers/specs/assets/mascot/吉祥物形象约定图4.png` | TaTa role consistency | Listening/hand-to-ear pose and calm expression | Decorative layout and labels only |

Notes:
- `t8-mascot-tata-style-sheet.png` is the canonical mascot reference for T8.0.
- `t8-mascot-tata-welcome-guide.png`, `t8-mascot-tata-listening.png`, and `t8-mascot-tata-success-shell.png` define TaTa's onboarding state references.
- `t8-phone-capture-after-trace.png` is the visual reference for the added L screen.
- `t8-motivation-layer-preview.png` is a light T9/T10 engagement-layer preview, not a T8 main-flow implementation requirement.
- The four `assets/mascot/吉祥物形象约定图*.png` sheets are TaTa character-consistency references.

### B. Superseded / Mood-Only Legacy References

These early images are retained only for pacing, layout, and density reference. They are not the active T8 implementation visual source of truth. Their generic parent-child guide, old sprout-like mascot direction, and missing phone-capture step have been superseded by TaTa plus L Save Trace / Phone Capture.

| Image | Path | May still inform | Superseded boundary |
| --- | --- | --- | --- |
| Flow overview storyboard | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-flow-overview-storyboard.png` | One-screen-one-question rhythm, progress, CTA cadence | A-K only; missing L phone capture; old guide is not final mascot |
| Welcome | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-screen-a-welcome.png` | Warm welcome mood and strong CTA placement | Parent-child illustration is not active mascot direction |
| Question template | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-question-template-scene.png` | Progress bar, large tappable options, selected state, pinned CTA | Generic guide art must be replaced by TaTa |
| First utterance / listen | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-first-utterance-listen.png` | Phrase stability, audio state, CTA swap from `听一下` to `我说了` | Old guide art must be replaced by TaTa listening state |
| Reaction / next support | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-reaction-next-support.png` | Reaction labels and next support layout | Emoji-like reaction faces and old guide art are mood only |
| Trace / Today handoff | `docs/superpowers/specs/assets/2026-07-02-t8-visual-interaction-contract/t8-trace-today-handoff.png` | Tiny trace and Today continuity mood | Missing L phone capture; trace handoff now requires TaTa shell success beat |

Implementation boundary:
- Do not treat any legacy parent-child guide as the final mascot.
- Do not use legacy images as active source-of-truth for TaTa.
- Do not infer that phone capture is optional to the contract because older images lack it.

Reference boundary:
- The uploaded Duolingo recording/contact sheet is pacing reference only.
- No Duolingo screenshot, frame, recording, brand asset, owl, green mascot, or copied UI is committed by this contract.
- Concept image text is not production UI. Native code text must follow this document.

## 6. Component System

### OnboardingFlowShell

Owns SafeArea, warm paper background, max width, fixed progress slot, TaTa guide slot, content slot, feedback slot, and bottom CTA.

Required slots:

```text
topProgress
tataGuideArea
titleArea
contentArea
feedbackArea
bottomCta
```

Rules:
- One primary CTA per screen.
- CTA never falls below safe area.
- Avoid nested cards around every section.
- 390x844 and 427x952 at text scale 1.3 must fit.

### Progress Bar

Purpose: onboarding step orientation, not course progress.

Rules:
- B-K count as 10 steps.
- L may show complete/protected save state separately.
- M has no onboarding progress.
- Progress advances only after committed steps.
- Semantics may say `第 3 步，共 10 步`; visible text may be hidden.

### TaTa Guide Area

Rules:
- Uses TaTa, not generic parent-child art or 小芽.
- Guide bubble max 1-2 short lines.
- TaTa can blink, nod, listen, or shell-glow for feedback.
- TaTa must not become an external teacher, scorer, or recording agent.

### Question Page

Rules:
- One question, native text.
- Large tappable options.
- Option selection does not advance.
- CTA commits.
- Feedback strip strengthens choice confidence.

### Option Card

Rules:
- Minimum 48dp touch target.
- 16dp radius.
- Selected: soft teal surface, teal border, check mark, optional TaTa nod/shell glow.
- Disabled state is rare; do not show unavailable normal options.

### Utterance Card

Rules:
- English phrase is the largest text on first utterance/listen/next support screens.
- English color uses `--english`.
- Chinese support and when-to-say remain native text.
- Speaker/play only; no microphone/recording/waveform as main action.

### Reaction Choices

Rules:
- Labels: `配合 / 犹豫 / 不想 / 没反应 / 其他`.
- Do not show enum names.
- Wrap or scroll at 1.3 text scale.

### Trace Card

Rules:
- Small care trace, not Garden/Growth redesign.
- May show shell glow or tiny sprout.
- Can lightly imply first continuity mark.

### Phone Capture Card

Rules:
- Warm save-progress framing.
- One phone field.
- Primary CTA and quiet secondary CTA.
- No password wall, CAPTCHA-first, social-login clutter, or cold auth styling.

## 7. Visual Tokens

These extend `DESIGN.md` Warm Paper Kindness.

| Token | Value | Contract |
| --- | --- | --- |
| Background | `#FFF8F0` | Warm paper base |
| Surface | `#FFFCF7` | Cards and form surfaces |
| Sunken | `#F5F0EB` | Progress track/recessed areas |
| Text | `#2D2926` | Primary warm brown |
| Muted text | `#6B5E57` / `#8A7D76` | Secondary/helper |
| CTA accent | `#FF8C42` | Main CTA only |
| CTA dark | `#E67A30` | Pressed/contrast |
| English / support teal | `#3B8577` | English phrase, audio, selected border |
| Selected soft | `#D4E8E3` | Selected option/reaction |
| Trace soft | `#E8F0E5` | Trace and energy hints |
| TaTa fur | warm brown / tan | Match style sheet |
| TaTa face/belly | cream white | Match style sheet |
| TaTa scarf | muted teal | Match style sheet |
| TaTa shell | pale shell pink | Shell resource/trace motif |
| Radius sm | `8dp` | Buttons, small tags |
| Radius md | `16dp` | Cards/options |
| Radius lg | `24dp` | Large panels |
| Shadow | warm rgba(45,41,38,0.06-0.12) | No cold dashboard shadow |
| English phrase | 28-34sp serif display | Fraunces or fallback |
| CTA text | 16-17sp bold | Native text |

## 8. Interaction Contract

1. Option selected does not auto-advance.
2. CTA advances question steps.
3. Progress advances only on committed step.
4. `听一下` does not write an event.
5. Audio failure does not block `我说了`.
6. `我说了` opens the said/reaction path; it does not call `recordReaction()`.
7. Reaction save is the first persisted care-turn event.
8. Reaction save uses existing `BabyReactionType`; no new reaction type.
9. Reaction save must pass through `care_path`, `CarePathNotifier`, `CarePathRepository.recordReaction()`, and `PracticeRepository.recordReaction()`.
10. Next support appears after reaction save or safe queued-local state.
11. Trace appears before phone capture.
12. Phone capture appears after trace and before Today.
13. Phone capture is post-value and optional through `稍后再说`.
14. Today handoff reads real local continuity, not a mock onboarding-only summary.
15. TaTa feedback can be stronger than the first draft, but it must not judge pronunciation or baby performance.

## 9. Motion Contract

| Motion | Timing | Behavior |
| --- | --- | --- |
| Page transition | 220-280ms | Fade + 8-12dp slide |
| Progress advance | 180-240ms | Smooth fill after commit |
| Option lift | 120-160ms | Small lift/scale, then settle |
| TaTa blink/nod | 120-220ms | Choice confirmation |
| Shell glow | 300-500ms | Trace/save success beat, no confetti burst |
| CTA press | 80-120ms | Scale/opacity + haptic |
| Feedback strip | 160-220ms | Fade/slide in |
| Audio state | 700-1200ms loop | Gentle pulse/ripple, no recording waveform |
| Phone card entry | 220-320ms | Warm bottom/card reveal |

Reduced motion:
- Disable repeated pulses and lifts.
- Keep state changes visible through static styling.
- Shell glow becomes a static highlight.

## 10. Accessibility And Viewport Contract

Required viewport matrix:

```text
390x844 @ text scale 1.0
390x844 @ text scale 1.3
427x952 @ text scale 1.0
427x952 @ text scale 1.3
```

Rules:
- Touch target >= 48dp.
- Bottom CTA never clips or overlaps safe area.
- Reaction choices wrap/scroll at 1.3.
- Phone input and secondary CTA remain reachable at 390x844.
- TaTa can shrink or move above title on small screens.
- Selected state does not rely only on color.
- Screen reader order: progress -> TaTa guide -> title -> options/content -> feedback -> CTA.
- Progress semantics describe onboarding step, not course progress.
- Phone field semantics must identify it as optional save-progress capture if `稍后再说` is available.

## 11. Copy Firewall Contract

The copy firewall now has three classes.

### A. Strictly Forbidden Visible Copy / Concepts

```text
课程
第几课
学习进度
完成任务
答对
答错
发音分
lesson
quiz
```

Why forbidden:
1. They pull Baby Talk back toward course, classroom, quiz, and scoring products.
2. They make parents feel they or their child are being judged.
3. They weaken the core value: say one sentence inside a real care moment.
4. They turn Duolingo-like motivation into school-like learning.

### B. Conditionally Allowed Engagement Mechanics

#### XP

Duolingo role:
- Measures behavior/learning activity.
- Supports ranking, stage progression, and continued use.
- Is not spendable currency.

Baby Talk translation:

```text
亲子英语能量
照护英语能量
今日能量
```

Allowed:
- Activity measure for real care English behavior.
- Can represent parent saying one sentence, recording baby reaction, receiving next support, and using care scenes repeatedly.

Guardrails:
- Do not represent drill/question XP.
- Do not bind to correctness or pronunciation score.
- Do not dominate early T8 onboarding.
- Do not show `答对 + XP`.

T8 placement:
- Do not make XP a main T8 feature.
- Trace/phone capture/Today may lightly imply `今天的亲子英语能量开始了`.
- Complex XP belongs to T9/T10.

#### Coins / Gems

Duolingo role:
- Spendable resource for shop/boost/streak freeze/extra features.
- Distinct from XP because it is a resource/currency.

Baby Talk translation:

```text
小贝壳
阳光
花园能量
```

Preferred name: `小贝壳`, because TaTa naturally carries shells.

Allowed:
- Future accumulable resource.
- Future uses can include protecting continuity, sending encouragement, garden decoration, or small personalization rewards.

Guardrails:
- Do not make parenting feel like earning coins.
- Do not create a heavy game economy.
- Do not create payment pressure.
- Do not show complex economy in T8 first-run flow.

T8 placement:
- Shell appears as TaTa's prop and success glow.
- Do not show `获得 10 个贝壳`.
- If hinted, use light copy such as `TaTa 的小贝壳亮了一下`.

#### Streak / 连续打卡

Duolingo role:
- Encourages continuous use and habit formation.

Baby Talk translation:

```text
连续照护痕迹
最近常说
连续留下痕迹
```

Allowed:
- Express continuous companionship.
- Record family continuity in real care scenes.

Guardrails:
- No missed-day punishment.
- No shame recall.
- No parenting anxiety.

T8 placement:
- Trace may say or imply `第一条连续照护痕迹开始了`.
- Day counts, repair, and streak protection belong to T9/T10.

#### Leaderboard / 排行榜

Duolingo role:
- Uses activity/XP for social comparison and motivation.

Baby Talk translation:

```text
好友家庭进度
家庭圈互相鼓励
好友小河
```

Allowed:
- Future friends/family progress and encouragement.
- Can compare family participation, care traces, and energy in a soft social layer.

Guardrails:
- Do not rank child ability.
- Do not compare baby performance.
- Do not create parent anxiety.
- Do not show public competitive leaderboard in first-run onboarding.

T8 placement:
- Not visible in first-run flow.
- Documented as T9/T10 engagement layer.

#### Score

Duolingo role:
- Reflects language learning phase/progress or performance.

Baby Talk translation:

```text
家庭启蒙指数
亲子英语成长分
照护英语活跃度
```

Allowed:
- Future long-term family English reflection.
- Can measure parent speaking frequency, scene coverage, response to baby reaction, continuity traces, and richness of family English environment.

Guardrails:
- No quiz score.
- No pronunciation score.
- No child performance score.
- No correctness rate.
- No `宝宝表现不好`.
- No complex score panel in T8 first-run flow.

T8 placement:
- Not shown as a main panel.
- Phone capture or Today may lightly say `以后 TaTa 会帮你看到家庭英语启蒙的变化。`

### C. T8 Onboarding Placement Rule

```text
XP / 小贝壳 / streak / leaderboard / score 是未来 engagement layer。
T8 first-run onboarding 只保留轻量 success beat。
不要让激励系统遮住 first care-turn value。
```

T8 mainline remains:

```text
第一句
-> 听一下
-> 我说了
-> 宝宝反应
-> 下一句支持
-> 留下痕迹
-> 保存手机号
-> 进入今天
```

## 12. Prototype Gap Review Against Duolingo-Like Pacing

### Missing From Previous Concept

- Missing post-value phone/account capture.
- Mascot personality was too weak; TaTa must carry the whole flow.
- Success beat was too quiet; first trace plus shell glow is needed.
- Engagement boundaries were over-conservative and left no room for XP/shell/streak/leaderboard/score translation.
- Option feedback and guide feedback need stronger micro-reactions.
- Mini care-turn should feel like an onboarding exercise rhythm, not a normal feature page.

### Extra / Overdone In Previous Concept

- Too quiet and content-card-like; not enough motivation.
- Copy firewall over-blocked Duolingo-like motivation.
- Trace/Today handoff felt like a static summary instead of a save-progress handoff.
- Mascot was not brandable enough.
- Generic parent-child illustration competed with mascot ownership.

## 13. Implementation Handoff Notes

Future T8 implementation must follow these constraints:

1. T8 first-run onboarding must complete the first care-turn before the phone save screen.
2. Phone save screen can start as a visual/local-first contract; account integration can connect later.
3. TaTa is the unified mascot; do not use generic parent-child art as the guide body.
4. XP / 小贝壳 / streak / leaderboard / score are no longer forbidden concepts, but they are not complex T8 main-flow features.
5. T9/T10 can gradually expose the engagement layer.
6. T8 only reserves semantic and visual entry points for motivation.
7. Do not change backend.
8. Do not change `mobile_v2`.
9. Do not change reaction contract.
10. Do not add reaction type.
11. Do not do Garden/Growth visual refactor.
12. Do not crop concept PNGs into production Flutter assets.
13. Exact visible copy must remain native UI text and follow this contract, not raster image quirks.

Old public onboarding surfaces still need replacement in implementation:
- `OnboardingSceneScreen`
- `OnboardingNameScreen`
- `OnboardingPracticeScreen`
- `OnboardingCompleteScreen`
- `OnboardingGardenWelcomeScreen`

Reusable pieces remain allowed if adapted:
- Warm scaffold and primary CTA primitives.
- Progress bar primitive.
- Existing `care_path` / `CarePathNotifier` / `PracticeRepository.recordReaction()` flow.
- Existing canonical `BabyReactionType` mapping.

## 14. Explicitly Not In Scope

- No Flutter code in T8.0.
- No mobile source modification in T8.0.
- No tests modified in T8.0.
- No backend changes.
- No `mobile_v2` changes.
- No reaction contract changes.
- No new reaction type.
- No Garden/Growth visual refactor.
- No complete engagement system implementation.
- No Duolingo reference assets committed.
- No commit.

## 15. GSTACK Review Report

| Review lane | Status | Evidence / note |
| --- | --- | --- |
| T8 plan source | Used | Existing T8 plan remains the architecture base, with this contract correcting visual/interaction strategy. |
| User整改 brief | Applied | Added post-value phone capture, TaTa mascot, engagement mechanic translation, and Borrow/Adapt/Reject matrix. |
| Image Gen | Complete | Generated TaTa welcome/listening/shell, phone capture, and motivation preview with the otter reference as source. |
| Mascot reference | Locked | `t8-mascot-tata-style-sheet.png` and four `assets/mascot/吉祥物形象约定图*.png` registered as TaTa direction. |
| Scope guard | Pass for draft | Only docs/assets changed; no Flutter/backend/mobile_v2/test implementation. |
| External reference guard | Pass for draft | Duolingo references remain conceptual; no Duolingo frames/screenshots/recordings were added. |

UNRESOLVED: 0 for T8.0 revised draft handoff.

VERDICT: T8.0 visual interaction contract is ready for user review with TaTa as the mascot, post-value save-progress phone capture added, and the engagement layer translated instead of banned.
