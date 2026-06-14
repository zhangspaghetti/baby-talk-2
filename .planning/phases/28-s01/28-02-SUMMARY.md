---
phase: "28"
plan: "02"
---

# T02: Added optional childAgeMonths to the mentor chat request/command/provider chain with backward-compatible constructors.

**Added optional childAgeMonths to the mentor chat request/command/provider chain with backward-compatible constructors.**

## What Happened

I implemented the child-age threading at the three real boundaries used by this codebase. In `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`, I added `@JsonProperty("childAgeMonths") Integer childAgeMonths` to the nested `ChatRequest` record and forwarded it into `MentorService.ChatCommand` from the `/api/v1/mentor/chat` controller mapping. In `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`, I extended the nested `ChatCommand` record with nullable `Integer childAgeMonths` and passed that value into `MentorProvider.ProviderRequest` on the chat path so the provider/request context now carries the field for T04 to consume. In `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorProvider.java`, I extended `ProviderRequest` with nullable `Integer childAgeMonths` as the provider-side contract.

To keep the change additive and non-breaking, I appended the new field at the end of both public records and added overload constructors that preserve the old parameter lists by defaulting `childAgeMonths` to `null`. That avoided churn across existing tests and call sites while still making the field available on the live mentor chat path. I also added `MentorWebTest.chatAcceptsOptionalChildAgeMonthsWithoutBreakingExistingFlow()` to prove the REST endpoint accepts `{ "childAgeMonths": 6 }` without returning 400, and added `SpringAiMentorProviderTest.requestWithChildAgeMonthsRemainsBackwardCompatible()` to show a provider request carrying the new field still executes normally.

## Verification

Ran `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest="MentorWebTest,SpringAiMentorProviderTest"` after the final code changes. The command completed successfully, covering the new web test that POST `/api/v1/mentor/chat` accepts `childAgeMonths: 6` and the existing/no-field MentorWebTest cases that preserve backward compatibility when the field is absent. The rerun also included the new SpringAiMentorProvider unit test proving the provider remains null-safe/backward-compatible when `ProviderRequest.childAgeMonths` is populated.

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `./backend/mvnw -f backend/pom.xml -q -pl app-api -am test -Dtest="MentorWebTest,SpringAiMentorProviderTest"` | 0 | ✅ pass | 26400ms |

## Deviations

The planner referenced top-level `ChatCommand`/`ChatRequest` files, but in local reality both are nested records (`MentorService.ChatCommand` and `MentorController.ChatRequest`). I applied the change there. I also preserved old constructor signatures with overloads instead of mechanically updating every existing caller, which kept this task additive and reduced unrelated churn.

## Known Issues

None.

## Files Created/Modified

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/MentorController.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/MentorProvider.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java`
