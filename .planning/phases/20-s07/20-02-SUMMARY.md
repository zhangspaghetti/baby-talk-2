---
phase: "20"
plan: "02"
---

# T02: Added the S07 closure runbook and tightened mentor/distribution shell copy so the shared workspace now states the incident-first and release-only boundaries explicitly.

**Added the S07 closure runbook and tightened mentor/distribution shell copy so the shared workspace now states the incident-first and release-only boundaries explicitly.**

## What Happened

This task stayed inside the planned closure scope: I did not reopen mentor/distribution runtime work or add any new backend queries, storage, or auth abstractions. I added `docs/runbooks/m006-s07-mentor-distribution-closure.md` as the durable S07 composition note for a fresh reader. The runbook names the reader and post-read action, explains that S04 owns shell/auth truth, S10 owns mentor incident evidence, S11 owns distribution stats truth, and S07 owns the composed proof plus only surgical wording/diagnostic corrections. It also records when a future “recent conversation history” request must become a new plan rather than a UI tweak.

On the UI side I made the smallest copy-only alignment needed so the truthful boundary is visible before a user drills into detail panes. `admin-web/src/app/routes.tsx` now labels the workspace `Mentor Audit` and gives both mentor/distribution routes explicit boundary subtitles: mentor is incident-first evidence with live rate-limit context, not a full transcript; distribution is bounded release/share stats where channel applies only to release-side data. I matched that with top-of-page explanatory copy in `MentorAuditPage.tsx` and `DistributionStatsPage.tsx`, then updated the existing closure Playwright spec to assert the renamed mentor workspace label. The work stayed surgical and directly traceable to S07’s semantics/alignment goal.

For future inspection, the canonical path is now: read the new S07 runbook, open `/mentor/audits` and `/distribution/stats` through the shared shell, then rerun the repo-root proof pack. During verification, the first Playwright run failed before tests executed because Docker Desktop lost an extraction snapshot during compose build; rerunning the exact same command passed unchanged, confirming an environment-cache transient rather than a product regression.

## Verification

Ran the full slice closure verification bar after the copy/doc changes. `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest` passed, confirming the focused mentor/distribution admin contracts still hold. `npm --prefix admin-web run build` passed, confirming the route-title/page-copy changes compile cleanly. `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts mentor-distribution-closure.spec.ts` passed on rerun and proved the shared shell still exposes the correct workspaces, mentor still shows incident-first evidence plus the live rate-limit card, distribution still shows the release-only channel note and redacted detail rows, and the mentor workspace label now matches the truthful S07 semantics. `dart run tool/verify_m006_s07_mentor_distribution.dart` then passed from repo root, replaying the backend contract test, admin-web build, and browser proof pack end to end.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw.cmd -f backend/pom.xml -q -pl admin-api -am test -Dtest=AdminMentorAuditWebTest,AdminDistributionStatsWebTest` | 0 | ✅ pass | 33311ms |
| 2 | `npm --prefix admin-web run build` | 0 | ✅ pass | 27956ms |
| 3 | `npm --prefix admin-web run test:e2e -- access-and-landing.spec.ts mentor-audit.spec.ts distribution-stats.spec.ts mentor-distribution-closure.spec.ts` | 0 | ✅ pass | 107879ms |
| 4 | `dart run tool/verify_m006_s07_mentor_distribution.dart` | 0 | ✅ pass | 195456ms |

## Deviations

None. The implementation remained a doc/copy alignment task; the only test edit was updating the existing closure spec to match the renamed mentor workspace label.

## Known Issues

None. The first Playwright run hit a transient Docker Desktop extraction-snapshot cache failure during compose build, but the unchanged rerun passed, so no product-surface issue remains open.

## Files Created/Modified

- `docs/runbooks/m006-s07-mentor-distribution-closure.md`
- `admin-web/src/app/routes.tsx`
- `admin-web/src/pages/MentorAuditPage.tsx`
- `admin-web/src/pages/DistributionStatsPage.tsx`
- `admin-web/tests/mentor-distribution-closure.spec.ts`
