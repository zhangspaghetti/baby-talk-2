# Flutter Mobile Home A/B Prototype User Test Design

## Background

Baby Talk 2 Phase 1 is validating whether Chinese parents of 0-3 year-old babies will naturally speak short English phrases during everyday care routines. The mobile Home screen is the daily entry point for that behavior: it should tell a returning parent what to say today, make one-phrase practice feel easy, and let Xiaohe help with an immediate real-world scene.

Source context:

- `.gstack/ceo-plans/2026-04-02-baby-talk-phase1-consolidated.md`
- `docs/superpowers/specs/2026-05-26-flutter-mobile-home-design.md`
- `docs/superpowers/specs/2026-05-26-flutter-mobile-practice-design.md`
- Existing Home V23 prototype: `.superpowers/brainstorm/92854-1779768440/content/qa-mobile-home-v23-smart-home.html`

## Decision

Create a browser clickable A/B prototype for the Home screen before touching Flutter implementation. The prototype compares two directions:

- **A: Plan-led V23 baseline** - continue refining the current Home V23 structure, with today's phrase as the main plan card.
- **B: Scene-mentor direction** - make the screen feel like a real care-moment companion, with Xiaohe and the current parent-child scene more prominent.

B is the recommended main direction. A remains the usability baseline so the test can separate a better concept from a clearer conventional layout.

## Test Persona

The first round tests **returning parents who have already completed onboarding**.

This round does not test first-open comprehension, onboarding, account setup, or offline failure recovery. Those are separate states for later rounds.

## Goals

Validate whether a returning parent can:

1. Identify the recommended action within 3 seconds.
2. Start and complete one phrase without verbal instruction.
3. Return to Home and understand what changed.
4. Ask Xiaohe for a temporary real-life scene and receive a directly speakable phrase.
5. Feel that the page serves daily parenting, not a child-course dashboard.

## Non-Goals

The first prototype does not include:

- Real Flutter implementation.
- QA backend integration.
- Login, onboarding, profile, or account settings.
- Complete four-tab navigation behavior.
- Full Garden detail page.
- Real audio playback, speech recognition, pronunciation scoring, or AI latency.
- Multi-turn Xiaohe chat.
- Push notifications, sharing, payment, or community flows.

## Prototype Architecture

Use a browser clickable prototype with local static state. It should support side-by-side evaluation of A and B with the same task script and the same content data.

Suggested state model:

- `variant`: `plan-led` or `scene-mentor`
- `homeState`: `defaultPlan`, `practiceComplete`, or `temporaryScene`
- `selectedScene`: default care scene or temporary Xiaohe scene
- `practiceResult`: empty or one completed phrase summary

The prototype should not call APIs. QA backend usage starts only after the design passes browser testing and moves into Flutter user-level tests.

## Shared Content Data

Use realistic Chinese parent-facing copy. Avoid generic filler text.

Default scene:

- Scene: 睡前收玩具
- English phrase: `Let's put it back.`
- Chinese meaning: 我们把它放回去吧。
- Parent action: 一边把玩具放回盒子，一边轻轻说给宝宝听。
- Xiaohe note: 这句适合睡前收尾，不像命令，更像邀请宝宝一起完成。

Temporary scene examples:

- 宝宝不肯睡
- 洗澡时哭了
- 要出门但宝宝不配合

Each temporary Xiaohe response should return one primary phrase and up to two alternates. The first response must be short enough for a tired parent to say immediately.

## Variant A: Plan-Led V23 Baseline

### Screen Structure

Top to bottom:

1. Warm greeting with baby context and a light streak/day marker.
2. Today route pill, for example `照护场景 · 睡前收玩具`.
3. Main today phrase card with English phrase, Chinese meaning, audio icon, and primary CTA.
4. Xiaohe inline note explaining why this phrase fits today.
5. Small activity suggestions related to the phrase.
6. Garden trace preview as a quiet completion echo.
7. Static bottom navigation hint for 首页 / 发现 / 花园 / 成长.

### Interactions

Default plan:

- Primary CTA: `开始练一句`.
- Secondary action: `换个眼前场景` opens temporary Xiaohe state.

Practice complete:

- Main card changes to completed state.
- CTA changes to `再说一次` and `下一句稍后再来`.
- Garden trace preview shows a small new mark.
- Xiaohe gives one sentence of parent-centered feedback.

Temporary scene:

- The selected scene replaces the route pill and main phrase content.
- A visible return action restores today's plan.
- Copy makes clear this is a one-time help path, not a replacement for today's plan.

### Visual Strategy

A should be calm, legible, and low-risk. It uses the existing Warm Paper Kindness language: warm paper background, restrained cards, clear CTA, and English phrase prominence without a course-like dashboard feeling.

## Variant B: Scene-Mentor Direction

### Screen Structure

Top to bottom:

1. A parent-moment header, for example `今晚 3 分钟，陪宝宝收个尾`.
2. Xiaohe presence as a small mentor bubble tied to the current moment.
3. Scene card: parent action first, phrase embedded inside the scene.
4. Primary CTA: `试着说这一句`.
5. Quick scene rescue row: `宝宝不肯睡`, `洗澡哭了`, `要出门了`.
6. Gentle result echo after practice: what the parent just did and how it can be reused tonight.
7. Garden trace preview as secondary emotional feedback.
8. Static bottom navigation hint for 首页 / 发现 / 花园 / 成长.

### Interactions

Default plan:

- Parent sees a concrete care moment before seeing progress metrics.
- Xiaohe frames the phrase as something usable now, not a lesson unit.

Practice complete:

- Header changes to `刚刚完成一次亲子英语时刻`.
- Xiaohe confirms the value of the action.
- Garden trace grows quietly without stealing focus.

Temporary scene:

- Quick scene row opens Xiaohe suggestion sheet or inline expanded state.
- Xiaohe returns one primary phrase plus optional alternates.
- Actions: `练这句`, `换个更温柔的说法`, `回到今日计划`.

### Visual Strategy

B should feel more like a parenting companion than a course homepage. The screen should lead with life context, then phrase, then progress. Xiaohe should feel present but not dominant. Visual warmth comes from spacing, soft hierarchy, and useful copy rather than decorative childlike elements.

## User Test Script

Run A and B with the same tasks. Counterbalance order across testers when possible.

Task 1: Open Home and ask the tester, without explanation, what they think they should do today.

Task 2: Ask them to complete one phrase and return to Home.

Task 3: Ask what changed after completion and whether the feedback feels meaningful.

Task 4: Give a temporary scenario: `宝宝不肯睡，你现在想马上说一句英语安抚他。` Ask them to find help from Xiaohe.

Task 5: Ask which version feels more like something they would open during real parenting.

## Acceptance Criteria

Move from browser prototype to Flutter plus QA-backend testing only if one variant meets these gates:

1. At least 80% of testers complete one phrase and return Home without verbal instruction.
2. At least 70% can explain what changed on Home after completing the phrase.
3. No more than 1 out of 5 testers asks `我现在该做什么？` in the default state.
4. Quick Ask takes under 30 seconds from entry discovery to a speakable suggestion.
5. Testers describe Xiaohe as a helpful parent-child English mentor, not a generic chatbot.
6. Testers can identify the primary phrase before noticing Garden or progress details.
7. The chosen visual direction is described as warm, usable, and parent-facing rather than childish or course-heavy.

## Risk Notes From Second Opinions

Product manager review:

- The three-state scope is sufficient for a first round and should not expand into long-term retention or backend quality.
- The largest risk is that completion feedback feels like task check-in instead of a meaningful parent-child moment.

Codex review:

- The scope is sufficient for returning-user daily flow, but not for first-use comprehension.
- Garden trace may create false confidence because clicking a visual reward is easier than understanding its long-term meaning.
- Quick Ask may feel faster in prototype than it will with real AI latency.

Rapid prototyper review:

- A is the baseline for clear plan/task hierarchy.
- B should be the recommended direction because it better validates the Phase 1 promise: English inside real parenting moments.

## QA Backend Boundary

Browser prototype testing uses static data only. After one variant passes the acceptance criteria, Flutter user-level testing can connect to QA backend and verify:

- Home loads the real resolved daily plan.
- Practice completion writes result state and returns a visible Home update.
- Xiaohe temporary scene handles real latency, loading, fallback, and offline/stale cache states.
- The four-tab shell does not obscure Home's primary action.

## Open Decisions For Implementation Planning

These are intentionally deferred until after user review of this design:

1. Whether the prototype is implemented by extending the existing Home V23 HTML file or by creating a new side-by-side comparison artifact.
2. Whether Variant B uses an inline expanded Xiaohe state or a bottom sheet for temporary scene help.
3. Which exact Flutter test harness will drive later user-level QA: widget tests, integration_test, or external browser/device automation.
4. How to reconcile the current two-tab Flutter shell with the Phase 1 four-tab target.