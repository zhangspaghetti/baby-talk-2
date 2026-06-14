# Uncommitted Review And Staged Commit Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Audit the current dirty worktree, separate archive-only changes from behavior changes, and land a readable staged commit sequence with evidence for every commit.

**Architecture:** Use a six-part execution flow: Stage 0 inventory and exclusion gate, Stage 1 docs/archive commit, Stage 2A reusable mobile UI commit, Stage 2B screen/bootstrap behavior commit, Stage 2C integration coverage commit, Stage 2D tooling and scaffold decision commit, and an optional Stage 3 cleanup commit.

**Tech Stack:** Git, PowerShell/Git Bash, Markdown, Flutter/Dart, Android Gradle scaffold files, existing shell scripts, existing Flutter test commands.

---

### Task 0: Freeze inventory and classify keep-vs-noise files

**Files:**
- Review only: `.gitignore`
- Review only: `.metadata`
- Review only: `analysis_options.yaml`
- Review only: `android/.gitignore`
- Review only: `android/app/build.gradle.kts`
- Review only: `android/app/src/debug/AndroidManifest.xml`
- Review only: `android/app/src/main/AndroidManifest.xml`
- Review only: `android/app/src/main/kotlin/com/example/baby_talk_worktree_root/MainActivity.kt`
- Review only: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Review only: `android/app/src/main/res/drawable/launch_background.xml`
- Review only: `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- Review only: `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- Review only: `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- Review only: `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- Review only: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- Review only: `android/app/src/main/res/values-night/styles.xml`
- Review only: `android/app/src/main/res/values/styles.xml`
- Review only: `android/app/src/profile/AndroidManifest.xml`
- Review only: `android/build.gradle.kts`
- Review only: `android/gradle.properties`
- Review only: `android/gradle/wrapper/gradle-wrapper.properties`
- Review only: `android/settings.gradle.kts`
- Review only: `baby_talk_worktree_root.iml`
- Review only: `android/baby_talk_worktree_root_android.iml`
- Review only: `docs/superpowers/plans/2026-05-30-garden-growth-backend-persistence.md`
- Review only: `docs/superpowers/reports/2026-05-30-backend-baseline-output-v2.txt`
- Review only: `lib/main.dart`

- [ ] **Step 1: Rebuild the current inventory snapshot before touching the index**

Run: `git status --short`
Expected: the pending set matches the files enumerated in this plan, with no surprise directories.

Run: `git diff --stat`
Expected: tracked-file diff remains centered in `docs/superpowers`, `mobile`, `scripts/qa-install-apk.sh`, and `.gitignore`.

Run: `git ls-files --others --exclude-standard .`
Expected: untracked set matches the plan, especially `docs/superpowers/specs/*`, `mobile/lib/app/widgets/*`, `mobile/test/*`, root Flutter scaffold files, and no hidden extra source directories.

- [ ] **Step 2: Record an explicit keep/drop decision for ambiguous files before any staging**

Default decision rules:
- Keep only if the file is intentional project source or durable documentation.
- Drop or ignore if the file is local IDE/runtime noise.

Required decisions:
- `.metadata`: default `drop-or-ignore`
- `baby_talk_worktree_root.iml`: default `drop-or-ignore`
- `android/baby_talk_worktree_root_android.iml`: default `drop-or-ignore`
- `docs/superpowers/plans/2026-05-30-garden-growth-backend-persistence.md`: keep only if it belongs to the already-landed garden-growth work; otherwise delete or leave unstaged.
- `docs/superpowers/reports/2026-05-30-backend-baseline-output-v2.txt`: keep only if it supersedes the already-committed baseline artifact; otherwise delete or leave unstaged.
- `analysis_options.yaml`, `android/**`, `lib/main.dart`: keep only if the repo is intentionally adopting a root Flutter runner/scaffold.

- [ ] **Step 3: Capture the known baseline blocker signature for later comparison**

Run: `cd mobile && flutter test test/widget_test.dart`
Expected: either PASS, or FAIL with the already-known baseline signature mentioning `BabyReactionType` / `wireValue`. Any new first-failure signature means stop and re-scope before committing.

- [ ] **Step 4: Do not stage anything until the keep/drop table is explicit**

Expected outcome:
- a short written classification list in working notes or commit scratchpad
- no partially staged files

### Task 1: Stage 1 archive-only docs commit

**Files:**
- Modify: `docs/superpowers/README.md`
- Modify: `docs/superpowers/specs/2026-05-26-flutter-mobile-home-design.md`
- Modify: `docs/superpowers/specs/2026-05-26-flutter-mobile-practice-design.md`
- Create: `docs/superpowers/plans/2026-05-30-uncommitted-review-and-staged-commit-implementation-plan.md`
- Create if retained: `docs/superpowers/plans/2026-05-30-garden-growth-backend-persistence.md`
- Create if retained: `docs/superpowers/reports/2026-05-30-backend-baseline-output-v2.txt`
- Create: `docs/superpowers/specs/2026-05-28-all-pages-design-decisions-summary.md`
- Create: `docs/superpowers/specs/2026-05-28-cicd-pipeline.md`
- Create: `docs/superpowers/specs/2026-05-28-cross-page-consistency-audit.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-architecture-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-discover-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-garden-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-garden-v2-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-growth-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-growth-v2-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-home-ab-prototype-refined.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-onboarding-v21-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-mobile-shell-v2-design.md`
- Create: `docs/superpowers/specs/2026-05-28-flutter-skill-review-summary.md`
- Create: `docs/superpowers/specs/2026-05-28-full-session-output-summary.md`
- Create: `docs/superpowers/specs/2026-05-28-home-ab-prototype.html`
- Create: `docs/superpowers/specs/2026-05-28-implementation-todos.md`
- Create: `docs/superpowers/specs/2026-05-28-onboarding-v21-discussion-summary.md`
- Create: `docs/superpowers/specs/2026-05-28-performance-optimization.md`
- Create: `docs/superpowers/specs/2026-05-28-security-compliance.md`
- Create: `docs/superpowers/specs/2026-05-29-component-spec-tech-review.md`
- Create: `docs/superpowers/specs/2026-05-31-flutter-ui-library-landscape-2026.md`
- Create: `docs/superpowers/specs/2026-05-31-inputfield-library-evaluation.md`
- Create: `docs/superpowers/specs/2026-06-01-extracted-components-library-replacement-eval.md`
- Create: `docs/superpowers/specs/archived/2026-05-28-flutter-mobile-shell-nav-design.md`
- Create: `docs/superpowers/specs/qa-mobile-discover-v1-browse.html`
- Create: `docs/superpowers/specs/qa-mobile-garden-v1-warm-garden.html`
- Create: `docs/superpowers/specs/qa-mobile-growth-v1-warm-growth.html`
- Create: `docs/superpowers/specs/qa-mobile-shell-v1-nav.html`

- [ ] **Step 1: Stage only archive/documentation files and nothing executable**

Run: `git add docs/superpowers/README.md docs/superpowers/specs/2026-05-26-flutter-mobile-home-design.md docs/superpowers/specs/2026-05-26-flutter-mobile-practice-design.md docs/superpowers/plans/2026-05-30-uncommitted-review-and-staged-commit-implementation-plan.md docs/superpowers/specs docs/superpowers/specs/archived`
Expected: only `docs/superpowers/**` paths are staged.

- [ ] **Step 2: Re-check the staged boundary before committing**

Run: `git diff --cached --name-only`
Expected: output contains only `docs/superpowers/**` paths approved for Stage 1.

Run: `git diff --cached --check`
Expected: no whitespace or conflict-marker errors.

- [ ] **Step 3: Commit the archive-only set**

Run: `git commit -m "docs(superpowers): archive mobile design and review artifacts"`
Expected: one docs-only commit with no source-code files included.

### Task 2: Stage 2A reusable mobile UI primitives and theme commit

**Files:**
- Modify: `mobile/lib/app/theme/app_layout_constants.dart`
- Modify: `mobile/lib/app/widgets/app_surface_card.dart`
- Create: `mobile/lib/app/widgets/app_audio_button.dart`
- Create: `mobile/lib/app/widgets/app_english_phrase.dart`
- Create: `mobile/lib/app/widgets/app_input_field.dart`
- Create: `mobile/lib/app/widgets/app_mentor_bubble.dart`
- Create: `mobile/lib/app/widgets/app_toast.dart`
- Create: `mobile/lib/app/widgets/xiaohe_fab.dart`
- Delete: `mobile/lib/features/onboarding/presentation/widgets/mentor_bubble.dart`
- Modify: `mobile/lib/features/practice/presentation/widgets/home_b_mentor_bubble.dart`
- Modify: `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`
- Modify: `mobile/test/app/widgets/app_surface_card_test.dart`
- Create: `mobile/test/app/widgets/app_audio_button_test.dart`
- Create: `mobile/test/app/widgets/app_english_phrase_test.dart`
- Create: `mobile/test/app/widgets/app_toast_test.dart`
- Create: `mobile/test/app/widgets/xiaohe_fab_test.dart`
- Create: `mobile/test/widgets/app_input_field_test.dart`
- Create: `mobile/test/widgets/mentor_bubble_form_test.dart`

- [ ] **Step 1: Stage only the reusable widget extraction slice**

Run: `git add mobile/lib/app/theme/app_layout_constants.dart mobile/lib/app/widgets/app_surface_card.dart mobile/lib/app/widgets/app_audio_button.dart mobile/lib/app/widgets/app_english_phrase.dart mobile/lib/app/widgets/app_input_field.dart mobile/lib/app/widgets/app_mentor_bubble.dart mobile/lib/app/widgets/app_toast.dart mobile/lib/app/widgets/xiaohe_fab.dart mobile/lib/features/practice/presentation/widgets/home_b_mentor_bubble.dart mobile/lib/features/practice/presentation/widgets/phrase_card.dart mobile/test/app/widgets/app_surface_card_test.dart mobile/test/app/widgets/app_audio_button_test.dart mobile/test/app/widgets/app_english_phrase_test.dart mobile/test/app/widgets/app_toast_test.dart mobile/test/app/widgets/xiaohe_fab_test.dart mobile/test/widgets/app_input_field_test.dart mobile/test/widgets/mentor_bubble_form_test.dart`

Run: `git add -u mobile/lib/features/onboarding/presentation/widgets/mentor_bubble.dart`
Expected: exactly the Stage 2A widget/theme files are staged, including the mentor bubble deletion.

- [ ] **Step 2: Run focused widget-level verification immediately after staging**

Run: `cd mobile && flutter test test/app/widgets/app_surface_card_test.dart test/app/widgets/app_audio_button_test.dart test/app/widgets/app_english_phrase_test.dart test/app/widgets/app_toast_test.dart test/app/widgets/xiaohe_fab_test.dart test/widgets/app_input_field_test.dart test/widgets/mentor_bubble_form_test.dart`
Expected: PASS. If the command fails, stop and split the slice again before committing.

- [ ] **Step 3: Commit the reusable widget extraction**

Run: `git commit -m "refactor(mobile): extract reusable practice ui widgets"`
Expected: one commit that can be reverted without touching screen flow or tooling files.

### Task 3: Stage 2B screen flow and bootstrap behavior commit

**Files:**
- Delete: `mobile/lib/app/session_bootstrap.dart`
- Modify: `mobile/lib/features/account/presentation/screens/account_entry_screen.dart`
- Modify: `mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart`
- Modify: `mobile/lib/features/practice/presentation/screens/practice_session_screen.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/test/app/app_route_contract_test.dart`
- Modify: `mobile/test/smoke/a11y_semantics_test.dart`
- Modify: `mobile/test/widget_test.dart`

- [ ] **Step 1: Stage only the screen/bootstrap slice**

Run: `git add mobile/lib/features/account/presentation/screens/account_entry_screen.dart mobile/lib/features/onboarding/presentation/screens/onboarding_screen.dart mobile/lib/features/practice/presentation/screens/practice_session_screen.dart mobile/lib/main.dart mobile/test/app/app_route_contract_test.dart mobile/test/smoke/a11y_semantics_test.dart mobile/test/widget_test.dart`

Run: `git add -u mobile/lib/app/session_bootstrap.dart`
Expected: the staged set contains only the screen-flow files and the session bootstrap deletion.

- [ ] **Step 2: Run the narrowest screen-contract checks**

Run: `cd mobile && flutter test test/app/app_route_contract_test.dart test/smoke/a11y_semantics_test.dart test/widget_test.dart`
Expected: either PASS, or FAIL with the same known baseline blocker signature from Task 0 (`BabyReactionType` / `wireValue`) and no new first-failure signature. If a new failure appears first, unstage and repair before commit.

- [ ] **Step 3: Commit the behavior slice**

Run: `git commit -m "feat(mobile): refresh onboarding account and practice flows"`
Expected: one behavior-oriented commit isolated from reusable widget extraction and integration tests.

### Task 4: Stage 2C integration and driver coverage commit

**Files:**
- Modify: `mobile/integration_test/s01_guest_practice_flow_test.dart`
- Modify: `mobile/integration_test/s02_personalized_onboarding_flow_test.dart`
- Modify: `mobile/integration_test/s03_account_sync_restore_flow_test.dart`
- Modify: `mobile/test_driver/app.dart`

- [ ] **Step 1: Stage only the integration coverage files**

Run: `git add mobile/integration_test/s01_guest_practice_flow_test.dart mobile/integration_test/s02_personalized_onboarding_flow_test.dart mobile/integration_test/s03_account_sync_restore_flow_test.dart mobile/test_driver/app.dart`
Expected: no screen, widget, docs, or script files are mixed into this commit.

- [ ] **Step 2: Run targeted integration compilation or execution**

Run: `cd mobile && flutter test integration_test/s01_guest_practice_flow_test.dart integration_test/s02_personalized_onboarding_flow_test.dart integration_test/s03_account_sync_restore_flow_test.dart`
Expected: either PASS, or FAIL with the same baseline blocker signature already recorded in Task 0. Any new failure that appears before the known blocker must be treated as a regression in this slice.

- [ ] **Step 3: Commit the integration slice**

Run: `git commit -m "test(mobile): align onboarding and restore integration flows"`
Expected: one test-only commit that can be cherry-picked independently.

### Task 5: Stage 2D tooling update commit

**Files:**
- Modify: `.gitignore`
- Modify: `scripts/qa-install-apk.sh`

- [ ] **Step 1: Stage only the repo/tooling delta**

Run: `git add .gitignore scripts/qa-install-apk.sh`
Expected: exactly two files are staged.

- [ ] **Step 2: Run the narrowest available tooling checks**

Run: `bash ./scripts/qa-install-apk.sh --help`
Expected: usage text is printed and the command exits 0.

Run: `git diff --cached --check`
Expected: no whitespace or merge-marker errors.

- [ ] **Step 3: Commit the tooling slice**

Run: `git commit -m "chore(tooling): refine qa install flow and local ignores"`
Expected: one tooling-only commit containing the adb reverse improvement and ignore-list changes.

### Task 6: Root Flutter scaffold adoption or rejection

**Files:**
- Create if intentionally adopted: `analysis_options.yaml`
- Create if intentionally adopted: `android/.gitignore`
- Create if intentionally adopted: `android/app/build.gradle.kts`
- Create if intentionally adopted: `android/app/src/debug/AndroidManifest.xml`
- Create if intentionally adopted: `android/app/src/main/AndroidManifest.xml`
- Create if intentionally adopted: `android/app/src/main/kotlin/com/example/baby_talk_worktree_root/MainActivity.kt`
- Create if intentionally adopted: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Create if intentionally adopted: `android/app/src/main/res/drawable/launch_background.xml`
- Create if intentionally adopted: `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- Create if intentionally adopted: `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- Create if intentionally adopted: `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- Create if intentionally adopted: `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- Create if intentionally adopted: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- Create if intentionally adopted: `android/app/src/main/res/values-night/styles.xml`
- Create if intentionally adopted: `android/app/src/main/res/values/styles.xml`
- Create if intentionally adopted: `android/app/src/profile/AndroidManifest.xml`
- Create if intentionally adopted: `android/build.gradle.kts`
- Create if intentionally adopted: `android/gradle.properties`
- Create if intentionally adopted: `android/gradle/wrapper/gradle-wrapper.properties`
- Create if intentionally adopted: `android/settings.gradle.kts`
- Create if intentionally adopted: `lib/main.dart`
- Exclude by default: `.metadata`
- Exclude by default: `baby_talk_worktree_root.iml`
- Exclude by default: `android/baby_talk_worktree_root_android.iml`

- [ ] **Step 1: Decide whether the repo actually wants a root Flutter app scaffold**

Acceptance rule:
- If the root scaffold is required for repo-level Flutter execution, keep `analysis_options.yaml`, `android/**`, and `lib/main.dart`.
- If it is only local worktree output, do not commit it; add ignore rules if needed and leave the files unstaged.

- [ ] **Step 2: If adopting, stage only intentional scaffold files and keep local IDE files out**

Run: `git add analysis_options.yaml lib/main.dart android/.gitignore android/app/build.gradle.kts android/app/src/debug/AndroidManifest.xml android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/com/example/baby_talk_worktree_root/MainActivity.kt android/app/src/main/res/drawable-v21/launch_background.xml android/app/src/main/res/drawable/launch_background.xml android/app/src/main/res/mipmap-hdpi/ic_launcher.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png android/app/src/main/res/values-night/styles.xml android/app/src/main/res/values/styles.xml android/app/src/profile/AndroidManifest.xml android/build.gradle.kts android/gradle.properties android/gradle/wrapper/gradle-wrapper.properties android/settings.gradle.kts`
Expected: `.metadata` and both `.iml` files remain unstaged.

- [ ] **Step 3: If adopting, run the cheapest scaffold validation**

Run: `flutter analyze lib/main.dart`
Expected: PASS, or at minimum no syntax/config errors originating from the newly added root scaffold files.

- [ ] **Step 4: Commit only if the scaffold decision is affirmative**

Run: `git commit -m "chore(flutter): add root android runner scaffold"`
Expected: one optional scaffold commit. If the scaffold is rejected, skip this task and explicitly clean or ignore the files instead.

### Task 7: Optional Stage 3 cleanup commit and final audit

**Files:**
- Cleanup candidates: `.metadata`
- Cleanup candidates: `baby_talk_worktree_root.iml`
- Cleanup candidates: `android/baby_talk_worktree_root_android.iml`
- Cleanup candidates: any unkept docs/report artifacts from Task 0

- [ ] **Step 1: Verify the remaining worktree after all intended commits**

Run: `git status --short`
Expected: either clean, or only explicitly rejected local-noise files remain.

- [ ] **Step 2: If local-noise files remain, resolve them in one small cleanup slice**

Preferred actions:
- add ignore rules if the files are recurring local artifacts
- delete the files if they are disposable generated output

Run: `git diff --cached --name-only`
Expected: only cleanup/noise-management files are staged.

- [ ] **Step 3: Commit cleanup only if it improves repeatability for future worktrees**

Run: `git commit -m "chore(repo): ignore local flutter worktree artifacts"`
Expected: optional final cleanup commit; skip if no cleanup change is needed.

- [ ] **Step 4: Produce the final evidence summary**

Run: `git log --oneline -n 8`
Expected: a readable top-of-history sequence close to this order:
- `docs(superpowers): archive mobile design and review artifacts`
- `refactor(mobile): extract reusable practice ui widgets`
- `feat(mobile): refresh onboarding account and practice flows`
- `test(mobile): align onboarding and restore integration flows`
- `chore(tooling): refine qa install flow and local ignores`
- optional `chore(flutter): add root android runner scaffold`
- optional `chore(repo): ignore local flutter worktree artifacts`

### Self-Review Gate

- [ ] Each commit has one dominant intent and can be reverted independently.
- [ ] Every commit was followed by a validation action, not only `git diff` inspection.
- [ ] No commit mixes `docs/superpowers/**` archive files with Dart behavior changes.
- [ ] No commit accidentally includes `.metadata` or `*.iml` unless there is an explicit rationale.
- [ ] The known mobile baseline blocker was compared consistently, and no new first-failure signature was introduced silently.
- [ ] Final `git status --short` is either clean or contains only intentionally deferred files.

### Execution Mode

1. Subagent-Driven (recommended)
2. Inline Execution