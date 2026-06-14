---
phase: "04"
plan: "02"
---

# T02: feat(chat-memory): integrate MessageChatMemoryAdvisor into ChatClient and add conversationId to ProviderRequest

**feat(chat-memory): integrate MessageChatMemoryAdvisor into ChatClient and add conversationId to ProviderRequest**

## What Happened

Implemented the core integration layer for conversation memory:

1. **ProviderRequest record**: Added `String conversationId` as the 9th field (after `requestedAt`), maintaining backward compatibility with null default from MentorService.

2. **MentorProviderConfiguration**: Added `ObjectProvider<MessageChatMemoryAdvisor> chatMemoryAdvisorProvider` parameter to `mentorProvider()` bean method. In `buildSpringAiProvider()`, the advisor is registered via `ChatClient.builder(chatModel).defaultAdvisors(chatMemoryAdvisor)` when non-null, degrading gracefully to no-memory mode when the bean is absent.

3. **SpringAiMentorProvider**: Updated `callChatClient()` to accept a `conversationId` parameter. When null/blank, a temporary UUID is generated for backward compatibility. Every request now calls `.advisors(a -> a.param(ChatMemory.CONVERSATION_ID, effectiveConversationId))` to pass the conversation ID to the memory advisor at runtime. Added SLF4J INFO log: `conversation.id={effectiveConversationId}`.

4. **MentorService**: Updated the ProviderRequest constructor call to pass `null` for conversationId (T03 will fill this in with real conversation tracking).

5. **Test updates**: All three test files updated:
   - `SpringAiMentorProviderTest`: Added `null` to sampleRequest(), added `advisors(Consumer)` mock stub
   - `AgenticMentorIntegrationTest`: Same updates
   - `MentorProviderConfigurationTest`: Added `ObjectProvider<MessageChatMemoryAdvisor>` mock field, updated all `configuration.mentorProvider()` calls to include the 4th parameter

Note: `ChatMemoryConfigurationTest` (created by T01) fails with `ExceptionInInitializerError` due to Testcontainers being unable to find Docker in this Windows environment — this is a pre-existing environment issue affecting all `AbstractIntegrationTest` subclasses, not related to T02 changes.

## Verification

- `mvn compile test-compile -q` → exit 0 (compilation clean)
- `mvn test -Dtest="SpringAiMentorProviderTest,AgenticMentorIntegrationTest,MentorProviderConfigurationTest"` → 33 tests run, 0 failures, 0 errors
- conversation.id UUID auto-generation confirmed in test output logs
- ChatMemoryConfigurationTest failure is pre-existing Docker/Testcontainers environment issue (not T02-related)

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 15000ms |
| 2 | `cd backend && mvn test -Dtest="SpringAiMentorProviderTest,AgenticMentorIntegrationTest,MentorProviderConfigurationTest" -pl .` | 0 | ✅ pass | 8044ms |
| 3 | `cd backend && mvn test -Dtest=ChatMemoryConfigurationTest -pl .` | 1 | ❌ fail (pre-existing: Testcontainers cannot find Docker environment on Windows) | 6564ms |

## Deviations

None.

## Known Issues

ChatMemoryConfigurationTest (from T01) fails in this environment due to Testcontainers unable to detect Docker Desktop's named pipe endpoint. All AbstractIntegrationTest subclasses are affected. This is a pre-existing environment issue, not introduced by T02.

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorProvider.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/service/MentorService.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/AgenticMentorIntegrationTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java`
