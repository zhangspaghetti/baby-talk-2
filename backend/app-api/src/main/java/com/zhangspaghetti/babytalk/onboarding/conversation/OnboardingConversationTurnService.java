package com.zhangspaghetti.babytalk.onboarding.conversation;

import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public final class OnboardingConversationTurnService {

    private static final Pattern SAFE_CONVERSATION_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{5,36}$");
    private static final Pattern SAFE_EVENT_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_.:-]{5,95}$");
    private static final Pattern SAFE_UTTERANCE_ID = Pattern.compile("^[A-Za-z0-9][A-Za-z0-9_-]{5,63}$");
    private static final Pattern SAFE_FACET = Pattern.compile("^[A-Za-z0-9_.:-]{1,80}$");
    private static final Set<String> REACTIONS = Set.of(
            "cooperating", "hesitant", "resisting", "no_response", "other");
    private static final Duration GENERATION_LEASE = Duration.ofSeconds(30);
    private static final Duration REPLAY_WAIT = Duration.ofSeconds(4);

    private final OnboardingConversationStore conversations;
    private final OnboardingConversationTurnStore turns;
    private final OnboardingConversationGenerator generator;
    private final PracticeGeneratedContentKeyFactory keys;
    private final OnboardingAudioCapabilityService audioCapabilities;
    private final Clock clock;

    @Autowired
    public OnboardingConversationTurnService(
            OnboardingConversationStore conversations,
            OnboardingConversationTurnStore turns,
            OnboardingConversationGenerator generator,
            PracticeGeneratedContentKeyFactory keys,
            OnboardingAudioCapabilityService audioCapabilities
    ) {
        this(conversations, turns, generator, keys, audioCapabilities, Clock.systemUTC());
    }

    OnboardingConversationTurnService(
            OnboardingConversationStore conversations,
            OnboardingConversationTurnStore turns,
            OnboardingConversationGenerator generator,
            PracticeGeneratedContentKeyFactory keys,
            OnboardingAudioCapabilityService audioCapabilities,
            Clock clock
    ) {
        this.conversations = conversations;
        this.turns = turns;
        this.generator = generator;
        this.keys = keys;
        this.audioCapabilities = audioCapabilities;
        this.clock = clock;
    }

    public Turn next(String conversationId, NextRequest request) {
        validateShape(conversationId, request);
        var conversation = conversations.findByConversationId(conversationId);
        var now = utcNow();
        validateConversation(conversation, request, now);
        var fingerprint = keys.onboardingTurnFingerprint(conversationId, canonicalRequest(request));
        var existing = turns.find(conversationId, request.localEventId());
        if (existing != null) {
            return awaitExisting(conversationId, request, fingerprint, conversation.expiresAt(), existing);
        }
        var turnId = "onbt_" + UUID.randomUUID().toString().replace("-", "");
        var reservation = new OnboardingConversationTurnStore.StoredTurn(
                turnId, conversationId, request.localEventId(), fingerprint,
                    request.previousUtteranceId(), request.parentAction(), request.reactionProvided(), request.reaction(),
                null, null, null, null, null, null, "generating",
                now.plus(GENERATION_LEASE), now, now);
        if (turns.reserve(reservation) == 0) {
            return awaitExisting(conversationId, request, fingerprint, conversation.expiresAt(),
                    turns.find(conversationId, request.localEventId()));
        }
        try {
            var generated = generator.generateNext(new OnboardingConversationGenerator.NextGenerationRequest(
                    conversation.installationRefHash(), conversation.installationOwnerKey(),
                    request.localEventId(), conversation.generationKey(),
                    Map.copyOf(request.generationScene().facets()), conversation.locale(), conversation.timeBand(),
                    request.previousUtteranceId(), conversation.englishText(), request.parentAction(),
                    request.reactionProvided().booleanValue(), request.reaction(), normalizedReactionText(request)));
            var completedAt = utcNow();
            if (turns.activate(
                    turnId, generated.generatedContentId(), generated.utteranceId(), generated.englishText(),
                    generated.chineseText(), generated.pronunciationHint(), generated.audioRef(),
                    conversation.expiresAt(), completedAt) != 1) {
                return awaitExisting(conversationId, request, fingerprint, conversation.expiresAt(),
                        turns.find(conversationId, request.localEventId()));
            }
            return response(turns.find(conversationId, request.localEventId()), conversation.expiresAt());
        } catch (RuntimeException exception) {
            turns.deleteReservation(turnId);
            throw exception;
        }
    }

    private Turn awaitExisting(
            String conversationId,
            NextRequest request,
            String fingerprint,
            OffsetDateTime expiresAt,
            OnboardingConversationTurnStore.StoredTurn initial
    ) {
        var turn = initial;
        var deadline = System.nanoTime() + REPLAY_WAIT.toNanos();
        var delayMillis = 25L;
        while (turn != null) {
            if (!fingerprint.equals(turn.requestFingerprint())) throw conflict();
            if ("active".equals(turn.status())) return response(turn, expiresAt);
            var now = utcNow();
            if (!turn.expiresAt().isAfter(now)) {
                turns.deleteExpiredReservation(conversationId, request.localEventId(), now);
                return next(conversationId, request);
            }
            if (System.nanoTime() >= deadline) break;
            try {
                Thread.sleep(delayMillis);
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                break;
            }
            delayMillis = Math.min(delayMillis * 2, 400L);
            turn = turns.find(conversationId, request.localEventId());
        }
        throw new ContractException(
                HttpStatus.SERVICE_UNAVAILABLE,
                "onboarding_generation_in_progress",
                "下一句仍在准备中，请稍后重试。");
    }

    private Turn response(OnboardingConversationTurnStore.StoredTurn turn, OffsetDateTime expiresAt) {
        var capability = audioCapabilities.issue(turn.conversationId(), turn.utteranceId(), expiresAt);
        return new Turn(
                turn.conversationId(), expiresAt,
                new OnboardingConversationService.Utterance(
                        turn.utteranceId(), turn.englishText(), turn.chineseText(),
                        turn.pronunciationHint(), capability, "remote_generated"));
    }

    private void validateShape(String conversationId, NextRequest request) {
        if (!matches(SAFE_CONVERSATION_ID, conversationId) || request == null
                || !matches(SAFE_EVENT_ID, request.localEventId())
                || !matches(SAFE_UTTERANCE_ID, request.previousUtteranceId())
                || !"said_it".equals(request.parentAction())
                || request.generationScene() == null) {
            throw invalid();
        }
        var scene = request.generationScene();
        if (!"babytalk.care".equals(scene.namespace()) || scene.version() != 1
                || scene.key() == null || scene.facets() == null || scene.facets().size() > 8
                || scene.facets().entrySet().stream().anyMatch(entry ->
                entry.getKey() == null || entry.getValue() == null
                        || entry.getKey().length() > 40 || entry.getValue().length() > 80
                        || !SAFE_FACET.matcher(entry.getKey()).matches()
                        || !SAFE_FACET.matcher(entry.getValue()).matches())) {
            throw invalid();
        }
        var reactionText = normalizedReactionText(request);
        if (Boolean.FALSE.equals(request.reactionProvided())) {
            if (request.reaction() != null || request.reactionText() != null) throw invalid();
            return;
        }
        if (!Boolean.TRUE.equals(request.reactionProvided())) throw invalid();
        if (!REACTIONS.contains(request.reaction())) throw invalid();
        if (!"other".equals(request.reaction()) && request.reactionText() != null) throw invalid();
        if ("other".equals(request.reaction())
                && request.reactionText() != null
                && (reactionText == null || reactionText.isEmpty() || reactionText.length() > 200)) {
            throw invalid();
        }
    }

    private void validateConversation(
            OnboardingConversationStore.StoredConversation conversation,
            NextRequest request,
            OffsetDateTime now
    ) {
        if (conversation == null || !"active".equals(conversation.status())
                || conversation.installationOwnerKey() == null
                || !conversation.expiresAt().isAfter(now)
                || !conversation.utteranceId().equals(request.previousUtteranceId())) {
            throw notFound();
        }
        var scene = request.generationScene();
        var storedFacets = conversation.generationFacetsJson().replaceAll("\\s", "");
        if (!conversation.generationNamespace().equals(scene.namespace())
                || !conversation.generationKey().equals(scene.key())
                || conversation.generationVersion() != scene.version()
                || !storedFacets.equals(canonicalFacets(scene.facets()))) {
            throw notFound();
        }
    }

    private String canonicalRequest(NextRequest request) {
        return segment(request.previousUtteranceId())
                + segment(request.parentAction())
                + segment(request.reactionProvided().toString())
                + segment(request.reaction() == null ? "" : request.reaction())
                + segment(normalizedReactionText(request) == null ? "" : normalizedReactionText(request))
                + segment(request.generationScene().namespace())
                + segment(request.generationScene().key())
                + segment(Integer.toString(request.generationScene().version()))
                + segment(canonicalFacets(request.generationScene().facets()));
    }

    private String canonicalFacets(Map<String, String> facets) {
        var members = facets.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> "\"" + entry.getKey() + "\":\"" + entry.getValue() + "\"")
                .reduce((left, right) -> left + "," + right)
                .orElse("");
        return "{" + members + "}";
    }

    private String segment(String value) {
        return value.length() + ":" + value;
    }

    private String normalizedReactionText(NextRequest request) {
        if (request.reactionText() == null) return null;
        return request.reactionText().trim();
    }

    private boolean matches(Pattern pattern, String value) {
        return value != null && pattern.matcher(value).matches();
    }

    private OffsetDateTime utcNow() {
        return OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
    }

    private ContractException invalid() {
        return new ContractException(HttpStatus.BAD_REQUEST, "invalid_onboarding_turn", "下一句请求无效。");
    }

    private ContractException notFound() {
        return new ContractException(HttpStatus.NOT_FOUND, "onboarding_conversation_not_found", "访客对话不可用。");
    }

    private ContractException conflict() {
        return new ContractException(HttpStatus.CONFLICT, "onboarding_idempotency_conflict", "本地事件已使用不同请求。");
    }

    public record NextRequest(
            String localEventId,
            String previousUtteranceId,
            String parentAction,
            Boolean reactionProvided,
            String reaction,
            String reactionText,
            GenerationScene generationScene
    ) {
    }

    public record GenerationScene(
            String namespace,
            String key,
            int version,
            Map<String, String> facets
    ) {
    }

    public record Turn(
            String conversationId,
            OffsetDateTime expiresAt,
            OnboardingConversationService.Utterance utterance
    ) {
    }
}
