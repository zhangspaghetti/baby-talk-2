package com.zhangspaghetti.babytalk.palace;

import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.kg.KgEntity;
import com.zhangspaghetti.babytalk.kg.KgEntityRepository;
import com.zhangspaghetti.babytalk.palace.PalaceKeywordRepository.ChunkResult;
import com.zhangspaghetti.babytalk.palace.projection.PalaceBridgeEdge;
import com.zhangspaghetti.babytalk.palace.projection.PalaceBridgeEdgeRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceProjectionVersionRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTraceRepository;
import com.zhangspaghetti.babytalk.palace.projection.PalaceRoom;
import com.zhangspaghetti.babytalk.palace.projection.PalaceRoomRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.document.Document;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class PalaceHybridRetrievalService {

    private static final Logger log = LoggerFactory.getLogger(PalaceHybridRetrievalService.class);

    private static final double KEYWORD_WEIGHT = 0.7d;
    private static final double DEFAULT_AGE_FLOOR = 0.5d;
    private static final double WIDENED_AGE_FLOOR = 0.8d;
    private static final double TRAVERSED_ROOM_MULTIPLIER = 1.05d;
    private static final Pattern AGE_RANGE_PATTERN = Pattern.compile("^(\\d+)\\s*-\\s*(\\d+)(?:\\D.*)?$");
    private static final List<String> SCORE_METADATA_KEYS = List.of(
            "score",
            "similarity",
            "similarity_score",
            "relevance",
            "relevance_score",
            "distance",
            "distance_score",
            "distanceScore"
    );

    private final PalaceSearchService palaceSearchService;
    private final PalaceKeywordRepository palaceKeywordRepository;
    private final KgEntityRepository kgEntityRepository;
    private final PalaceRoomRepository palaceRoomRepository;
    private final PalaceBridgeEdgeRepository palaceBridgeEdgeRepository;
    private final PalaceProjectionVersionRepository palaceProjectionVersionRepository;
    private final PalaceQueryTraceRepository palaceQueryTraceRepository;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    @Autowired
    public PalaceHybridRetrievalService(
            PalaceSearchService palaceSearchService,
            PalaceKeywordRepository palaceKeywordRepository,
            KgEntityRepository kgEntityRepository,
            PalaceRoomRepository palaceRoomRepository,
            PalaceBridgeEdgeRepository palaceBridgeEdgeRepository,
            PalaceProjectionVersionRepository palaceProjectionVersionRepository,
            PalaceQueryTraceRepository palaceQueryTraceRepository,
            ObjectMapper objectMapper) {
        this(
                palaceSearchService,
                palaceKeywordRepository,
                kgEntityRepository,
                palaceRoomRepository,
                palaceBridgeEdgeRepository,
                palaceProjectionVersionRepository,
                palaceQueryTraceRepository,
                objectMapper,
                Clock.systemUTC());
    }

    PalaceHybridRetrievalService(
            PalaceSearchService palaceSearchService,
            PalaceKeywordRepository palaceKeywordRepository,
            KgEntityRepository kgEntityRepository,
            PalaceRoomRepository palaceRoomRepository,
            PalaceBridgeEdgeRepository palaceBridgeEdgeRepository,
            PalaceProjectionVersionRepository palaceProjectionVersionRepository,
            PalaceQueryTraceRepository palaceQueryTraceRepository,
            ObjectMapper objectMapper,
            Clock clock) {
        this.palaceSearchService = palaceSearchService;
        this.palaceKeywordRepository = palaceKeywordRepository;
        this.kgEntityRepository = kgEntityRepository;
        this.palaceRoomRepository = palaceRoomRepository;
        this.palaceBridgeEdgeRepository = palaceBridgeEdgeRepository;
        this.palaceProjectionVersionRepository = palaceProjectionVersionRepository;
        this.palaceQueryTraceRepository = palaceQueryTraceRepository;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    public RetrievalResult retrieve(RetrievalRequest request) {
        RetrievalRequest safeRequest = request == null ? new RetrievalRequest("") : request;
        try {
            return retrieveInternal(safeRequest);
        } catch (Exception e) {
            log.error("hybrid retrieval failed, falling back to vector-only path: query='{}'", safeRequest.query(), e);
            return fallbackVectorOnly(safeRequest, e);
        }
    }

    private RetrievalResult retrieveInternal(RetrievalRequest request) {
        if (request.query().isBlank()) {
            QueryTrace trace = new QueryTrace(
                    inferEntryRoomLabels(request),
                    List.of(),
                    List.of(),
                    request.childAgeMonths() == null ? "skipped" : "soft-boost: child=%dmo, empty-query".formatted(request.childAgeMonths()),
                    List.of(),
                    "not-ready");
            persistTrace(trace, null);
            return new RetrievalResult(List.of(), trace);
        }

        ProjectionTraversal traversal = resolveProjectionTraversal(request);
        List<Document> vectorCandidates = palaceSearchService.search(
                request.query(),
                request.wingHint(),
                request.roomHint(),
                request.maxResults() * 2);
        List<ChunkResult> keywordCandidates = palaceKeywordRepository.searchByKeywords(
                request.query(),
                request.wingHint(),
                request.roomHint(),
                request.maxResults() * 2);
        AgeWindow kgAgeWindow = resolveKgAgeWindow(request);

        RankingOutcome rankingOutcome = rankCandidates(
                request,
                vectorCandidates,
                keywordCandidates,
                traversal.extraTraversedRoomKeys(),
                kgAgeWindow);

        QueryTrace trace = new QueryTrace(
                traversal.entryRooms(),
                traversal.roomsTraversed(),
                traversal.bridgeEdgesCrossed(),
                rankingOutcome.temporalRuleApplied(),
                rankingOutcome.candidates(),
                traversal.projectionVersionUsed());
        persistTrace(trace, null);

        log.info(
                "hybrid retrieval complete: query='{}', vectorCount={}, keywordCount={}, resultCount={}, temporalRule='{}', projectionVersion='{}'",
                request.query(),
                vectorCandidates.size(),
                keywordCandidates.size(),
                rankingOutcome.candidates().size(),
                trace.temporalRuleApplied(),
                trace.projectionVersionUsed());

        return new RetrievalResult(rankingOutcome.candidates(), trace);
    }

    private RetrievalResult fallbackVectorOnly(RetrievalRequest request, Exception cause) {
        List<HybridCandidate> candidates;
        try {
            RankingOutcome rankingOutcome = rankCandidates(
                    request,
                    palaceSearchService.search(request.query(), request.wingHint(), request.roomHint(), request.maxResults()),
                    List.of(),
                    Set.of(),
                    null);
            candidates = rankingOutcome.candidates();
        } catch (Exception vectorFailure) {
            log.error("vector-only fallback also failed: query='{}'", request.query(), vectorFailure);
            candidates = List.of();
        }

        String baseTemporalRule = request.childAgeMonths() == null
                ? "skipped"
                : "soft-boost: child=%dmo".formatted(request.childAgeMonths());
        String temporalRule = "error-fallback: %s; %s".formatted(compactMessage(cause), baseTemporalRule);
        QueryTrace trace = new QueryTrace(
                inferEntryRoomLabels(request),
                List.of(),
                List.of(),
                temporalRule,
                candidates,
                null);
        persistTrace(trace, null);
        return new RetrievalResult(candidates, trace);
    }

    private RankingOutcome rankCandidates(
            RetrievalRequest request,
            List<Document> vectorCandidates,
            List<ChunkResult> keywordCandidates,
            Set<String> traversedRoomKeys,
            AgeWindow kgAgeWindow) {
        Map<String, CandidateAccumulator> merged = new LinkedHashMap<>();
        addVectorCandidates(merged, vectorCandidates);
        addKeywordCandidates(merged, keywordCandidates);

        if (merged.isEmpty()) {
            return new RankingOutcome(List.of(), request.childAgeMonths() == null
                    ? "skipped"
                    : "soft-boost: child=%dmo, candidates=0".formatted(request.childAgeMonths()));
        }

        List<HybridCandidate> rankedWithDefaultFloor = buildRankedCandidates(
                merged.values(), request.childAgeMonths(), DEFAULT_AGE_FLOOR, traversedRoomKeys, kgAgeWindow, false);

        long countAboveDefaultFloor = rankedWithDefaultFloor.stream()
                .filter(candidate -> candidate.ageBoostApplied() > DEFAULT_AGE_FLOOR)
                .count();

        boolean fallbackApplied = request.childAgeMonths() != null
                && countAboveDefaultFloor < 3
                && !rankedWithDefaultFloor.isEmpty();

        List<HybridCandidate> finalCandidates = fallbackApplied
                ? buildRankedCandidates(merged.values(), request.childAgeMonths(), WIDENED_AGE_FLOOR, traversedRoomKeys, kgAgeWindow, true)
                : rankedWithDefaultFloor;

        finalCandidates = finalCandidates.stream()
                .sorted(Comparator
                        .comparingDouble(HybridCandidate::effectiveScore)
                        .reversed()
                        .thenComparing(HybridCandidate::chunkId))
                .limit(request.maxResults())
                .toList();

        String temporalRuleApplied = buildTemporalRule(request.childAgeMonths(), fallbackApplied, countAboveDefaultFloor, kgAgeWindow);
        return new RankingOutcome(finalCandidates, temporalRuleApplied);
    }

    private List<HybridCandidate> buildRankedCandidates(
            Collection<CandidateAccumulator> accumulators,
            Integer childAgeMonths,
            double ageFloor,
            Set<String> traversedRoomKeys,
            AgeWindow kgAgeWindow,
            boolean fallbackApplied) {
        List<HybridCandidate> ranked = new ArrayList<>();
        for (CandidateAccumulator accumulator : accumulators) {
            String ageRangeRaw = extractString(accumulator.metadata(), "age_range");
            AgeWindow explicitAgeWindow = parseAgeRange(ageRangeRaw).orElse(null);
            boolean usedKgHint = explicitAgeWindow == null && kgAgeWindow != null;
            AgeWindow effectiveAgeWindow = explicitAgeWindow != null ? explicitAgeWindow : kgAgeWindow;
            String candidateAgeRangeRaw = ageRangeRaw;
            if ((candidateAgeRangeRaw == null || candidateAgeRangeRaw.isBlank()) && usedKgHint) {
                candidateAgeRangeRaw = kgAgeWindow.rawLabel();
            }

            String roomKey = roomKey(accumulator.metadata());
            double traversedRoomFactor = traversedRoomKeys.contains(roomKey) ? TRAVERSED_ROOM_MULTIPLIER : 1.0d;
            double mergedScore = accumulator.hybridScore() * traversedRoomFactor;
            AgeBoost ageBoost = computeAgeBoost(childAgeMonths, effectiveAgeWindow, ageFloor);

            List<String> reasons = new ArrayList<>();
            reasons.add(accumulator.vectorScore() != null && accumulator.keywordScore() != null
                    ? "hybrid"
                    : accumulator.vectorScore() != null ? "vector-only" : "keyword-only");
            if (traversedRoomFactor > 1.0d) {
                reasons.add("projection-room-match");
            }
            if (usedKgHint) {
                reasons.add("kg-age-hint");
            }
            if (candidateAgeRangeRaw == null || candidateAgeRangeRaw.isBlank()) {
                reasons.add("age-range-missing");
            } else if (explicitAgeWindow == null && !usedKgHint) {
                reasons.add("age-range-unparseable");
            }
            if (fallbackApplied) {
                reasons.add("temporal-fallback-floor-0.8");
            }
            reasons.add(ageBoost.reason());

            ranked.add(new HybridCandidate(
                    accumulator.chunkId(),
                    accumulator.content(),
                    accumulator.vectorScore(),
                    accumulator.keywordScore(),
                    mergedScore,
                    candidateAgeRangeRaw,
                    ageBoost.factor(),
                    String.join(", ", reasons),
                    extractString(accumulator.metadata(), "source_book")));
        }
        return ranked;
    }

    private void addVectorCandidates(Map<String, CandidateAccumulator> merged, List<Document> vectorCandidates) {
        for (int i = 0; i < vectorCandidates.size(); i++) {
            Document document = vectorCandidates.get(i);
            String chunkId = document.getId();
            if (chunkId == null || chunkId.isBlank()) {
                chunkId = stableFallbackChunkId(document.getText(), i);
            }
            String effectiveChunkId = chunkId;
            double vectorScore = extractVectorScore(document, i, vectorCandidates.size());
            merged.computeIfAbsent(effectiveChunkId, ignored -> CandidateAccumulator.empty(effectiveChunkId))
                    .mergeVector(document.getText(), vectorScore, document.getMetadata());
        }
    }

    private void addKeywordCandidates(Map<String, CandidateAccumulator> merged, List<ChunkResult> keywordCandidates) {
        for (int i = 0; i < keywordCandidates.size(); i++) {
            ChunkResult chunk = keywordCandidates.get(i);
            String chunkId = chunk.id() == null ? stableFallbackChunkId(chunk.content(), i) : chunk.id().toString();
            double keywordScore = chunk.keywordScore() != null
                    ? chunk.keywordScore()
                    : rankFallbackScore(i, keywordCandidates.size());
            merged.computeIfAbsent(chunkId, ignored -> CandidateAccumulator.empty(chunkId))
                    .mergeKeyword(chunk.content(), keywordScore, chunk.metadata());
        }
    }

    private ProjectionTraversal resolveProjectionTraversal(RetrievalRequest request) {
        long roomCount = palaceRoomRepository.count();
        if (roomCount == 0) {
            return new ProjectionTraversal(
                    inferEntryRoomLabels(request),
                    List.of(),
                    List.of(),
                    Set.of(),
                    "not-ready");
        }

        Long projectionVersion = palaceProjectionVersionRepository.findCurrentVersion()
                .map(version -> version.getVersionNum())
                .orElse(null);

        List<PalaceRoom> entryRooms = resolveEntryRooms(request);
        if (entryRooms.isEmpty()) {
            return new ProjectionTraversal(
                    List.of(),
                    List.of(),
                    List.of(),
                    Set.of(),
                    projectionVersion == null ? null : projectionVersion.toString());
        }

        LinkedHashMap<UUID, PalaceRoom> visitedRooms = new LinkedHashMap<>();
        for (PalaceRoom room : entryRooms) {
            visitedRooms.put(room.getId(), room);
        }
        LinkedHashSet<UUID> visitedIds = new LinkedHashSet<>(visitedRooms.keySet());
        ArrayDeque<UUID> frontier = new ArrayDeque<>(visitedRooms.keySet());
        List<PalaceBridgeEdge> crossedEdges = new ArrayList<>();

        for (int hop = 0; hop < request.maxHops() && !frontier.isEmpty(); hop++) {
            List<UUID> frontierIds = new ArrayList<>(frontier);
            frontier.clear();
            List<PalaceBridgeEdge> edges = palaceBridgeEdgeRepository.findApprovedEdgesForRooms(frontierIds);
            for (PalaceBridgeEdge edge : edges) {
                UUID nextRoomId = resolveNextRoomId(frontierIds, edge);
                crossedEdges.add(edge);
                if (nextRoomId != null && visitedIds.add(nextRoomId)) {
                    frontier.add(nextRoomId);
                }
            }
            if (!frontier.isEmpty()) {
                palaceRoomRepository.findAllById(new ArrayList<>(frontier))
                        .forEach(room -> visitedRooms.put(room.getId(), room));
            }
        }

        List<String> entryRoomLabels = entryRooms.stream()
                .map(this::roomKey)
                .distinct()
                .toList();
        List<String> visitedRoomLabels = visitedRooms.values().stream()
                .map(this::roomKey)
                .distinct()
                .toList();
        Set<String> extraTraversedRooms = visitedRoomLabels.stream()
                .filter(label -> !entryRoomLabels.contains(label))
                .collect(LinkedHashSet::new, Set::add, Set::addAll);
        List<String> bridgeEdgeLabels = crossedEdges.stream()
                .map(edge -> describeBridgeEdge(edge, visitedRooms))
                .distinct()
                .toList();

        return new ProjectionTraversal(
                entryRoomLabels,
                visitedRoomLabels,
                bridgeEdgeLabels,
                extraTraversedRooms,
                projectionVersion == null ? null : projectionVersion.toString());
    }

    private List<PalaceRoom> resolveEntryRooms(RetrievalRequest request) {
        if (request.wingHint() != null && request.roomHint() != null) {
            return palaceRoomRepository.findByWingAndRoom(request.wingHint(), request.roomHint())
                    .map(List::of)
                    .orElseGet(List::of);
        }
        if (request.wingHint() != null) {
            return palaceRoomRepository.findByWing(request.wingHint());
        }
        if (request.roomHint() != null) {
            return palaceRoomRepository.findAll().stream()
                    .filter(room -> request.roomHint().equals(room.getRoom()))
                    .toList();
        }
        return List.of();
    }

    private AgeWindow resolveKgAgeWindow(RetrievalRequest request) {
        try {
            List<KgEntity> matches = kgEntityRepository.findByNameLike(request.query()).stream()
                    .filter(entity -> request.wingHint() == null || request.wingHint().equals(normalize(entity.wing())))
                    .filter(entity -> request.roomHint() == null || request.roomHint().equals(normalize(entity.room())))
                    .filter(entity -> entity.validFromMonths() != null && entity.validToMonths() != null)
                    .toList();
            if (matches.isEmpty()) {
                return null;
            }
            int min = matches.stream().map(KgEntity::validFromMonths).min(Integer::compareTo).orElse(0);
            int max = matches.stream().map(KgEntity::validToMonths).max(Integer::compareTo).orElse(min);
            return new AgeWindow(min, max, "kg:%d-%dmo".formatted(min, max));
        } catch (Exception e) {
            log.warn("kg entity hint lookup failed for query='{}': {}", request.query(), e.getMessage());
            return null;
        }
    }

    private AgeBoost computeAgeBoost(Integer childAgeMonths, AgeWindow ageWindow, double floor) {
        if (childAgeMonths == null) {
            return new AgeBoost(1.0d, "age-skipped");
        }
        if (ageWindow == null) {
            return new AgeBoost(1.0d, "age-missing");
        }
        if (childAgeMonths >= ageWindow.fromMonths() && childAgeMonths <= ageWindow.toMonths()) {
            return new AgeBoost(1.0d, "age-in-range");
        }
        int gap = childAgeMonths < ageWindow.fromMonths()
                ? ageWindow.fromMonths() - childAgeMonths
                : childAgeMonths - ageWindow.toMonths();
        double factor = Math.max(floor, 1.0d - (gap / 24.0d));
        return new AgeBoost(factor, "age-gap=%dmo".formatted(gap));
    }

    private String buildTemporalRule(Integer childAgeMonths, boolean fallbackApplied, long countAboveDefaultFloor, AgeWindow kgAgeWindow) {
        if (childAgeMonths == null) {
            return "skipped";
        }
        StringBuilder builder = new StringBuilder("soft-boost: child=")
                .append(childAgeMonths)
                .append("mo, defaultFloor=")
                .append(DEFAULT_AGE_FLOOR)
                .append(", candidatesAboveDefaultFloor=")
                .append(countAboveDefaultFloor);
        if (fallbackApplied) {
            builder.append(", fallback-floor-0.8");
        }
        if (kgAgeWindow != null) {
            builder.append(", kg-hint=").append(kgAgeWindow.rawLabel());
        }
        return builder.toString();
    }

    private void persistTrace(QueryTrace trace, String installationId) {
        try {
            com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTrace entity =
                    new com.zhangspaghetti.babytalk.palace.projection.PalaceQueryTrace(
                            null,
                            objectMapper.valueToTree(trace.entryRooms()),
                            trace.temporalRuleApplied(),
                            objectMapper.valueToTree(trace.candidates()),
                            objectMapper.valueToTree(trace.bridgeEdgesCrossed()),
                            toProjectionVersionLong(trace.projectionVersionUsed()),
                            Instant.now(clock),
                            installationId);
            palaceQueryTraceRepository.save(entity);
        } catch (Exception e) {
            log.warn(
                    "event=palace_trace_persistence_failed exceptionType={} candidateCount={} entryRoomCount={} bridgeEdgeCount={}",
                    e.getClass().getSimpleName(),
                    trace.candidates().size(),
                    trace.entryRooms().size(),
                    trace.bridgeEdgesCrossed().size());
        }
    }

    private Long toProjectionVersionLong(String projectionVersionUsed) {
        if (projectionVersionUsed == null || projectionVersionUsed.isBlank() || "not-ready".equals(projectionVersionUsed)) {
            return null;
        }
        try {
            return Long.parseLong(projectionVersionUsed);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Optional<AgeWindow> parseAgeRange(String rawAgeRange) {
        if (rawAgeRange == null || rawAgeRange.isBlank()) {
            return Optional.empty();
        }
        Matcher matcher = AGE_RANGE_PATTERN.matcher(rawAgeRange.trim());
        if (!matcher.matches()) {
            return Optional.empty();
        }
        int fromYears = Integer.parseInt(matcher.group(1));
        int toYears = Integer.parseInt(matcher.group(2));
        return Optional.of(new AgeWindow(fromYears * 12, toYears * 12, rawAgeRange.trim()));
    }

    private double extractVectorScore(Document document, int index, int total) {
        Map<String, Object> metadata = document.getMetadata();
        for (String key : SCORE_METADATA_KEYS) {
            Double score = asDouble(metadata.get(key));
            if (score == null) {
                continue;
            }
            if (key.toLowerCase(Locale.ROOT).contains("distance")) {
                return 1.0d / (1.0d + Math.max(0.0d, score));
            }
            return score;
        }
        return rankFallbackScore(index, total);
    }

    private double rankFallbackScore(int index, int total) {
        return Math.max(0.1d, 1.0d - ((double) index / Math.max(1, total)));
    }

    private Double asDouble(Object value) {
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        if (value instanceof String string && !string.isBlank()) {
            try {
                return Double.parseDouble(string.trim());
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private String stableFallbackChunkId(String content, int index) {
        return "fallback-%d-%d".formatted(index, Objects.hashCode(content));
    }

    private String compactMessage(Exception exception) {
        String message = exception.getMessage();
        if (message == null || message.isBlank()) {
            return exception.getClass().getSimpleName();
        }
        String compact = message.replaceAll("\\s+", " ").trim();
        return compact.length() <= 120 ? compact : compact.substring(0, 120);
    }

    private List<String> inferEntryRoomLabels(RetrievalRequest request) {
        if (request.wingHint() != null && request.roomHint() != null) {
            return List.of(roomKey(request.wingHint(), request.roomHint()));
        }
        if (request.wingHint() != null) {
            return List.of(request.wingHint());
        }
        if (request.roomHint() != null) {
            return List.of(request.roomHint());
        }
        return List.of();
    }

    private String describeBridgeEdge(PalaceBridgeEdge edge, Map<UUID, PalaceRoom> visitedRooms) {
        PalaceRoom roomA = visitedRooms.get(edge.getRoomAId());
        PalaceRoom roomB = visitedRooms.get(edge.getRoomBId());
        if (roomA == null || roomB == null) {
            return edge.getId().toString();
        }
        return "%s<->%s".formatted(roomKey(roomA), roomKey(roomB));
    }

    private UUID resolveNextRoomId(List<UUID> frontierIds, PalaceBridgeEdge edge) {
        boolean containsA = frontierIds.contains(edge.getRoomAId());
        boolean containsB = frontierIds.contains(edge.getRoomBId());
        if (containsA && !containsB) {
            return edge.getRoomBId();
        }
        if (containsB && !containsA) {
            return edge.getRoomAId();
        }
        return null;
    }

    private String roomKey(PalaceRoom room) {
        return roomKey(room.getWing(), room.getRoom());
    }

    private String roomKey(Map<String, Object> metadata) {
        String wing = extractString(metadata, "wing");
        String room = extractString(metadata, "room");
        if (wing == null || room == null) {
            return "";
        }
        return roomKey(wing, room);
    }

    private String roomKey(String wing, String room) {
        return "%s/%s".formatted(normalize(wing), normalize(room));
    }

    private String extractString(Map<String, Object> metadata, String key) {
        if (metadata == null) {
            return null;
        }
        Object value = metadata.get(key);
        if (value == null) {
            return null;
        }
        String stringValue = value.toString().trim();
        return stringValue.isEmpty() ? null : stringValue;
    }

    private String normalize(String value) {
        return value == null ? null : value.trim().toLowerCase(Locale.ROOT);
    }

    private record AgeBoost(double factor, String reason) {
    }

    private record AgeWindow(int fromMonths, int toMonths, String rawLabel) {
    }

    private record RankingOutcome(List<HybridCandidate> candidates, String temporalRuleApplied) {
    }

    private record ProjectionTraversal(
            List<String> entryRooms,
            List<String> roomsTraversed,
            List<String> bridgeEdgesCrossed,
            Set<String> extraTraversedRoomKeys,
            String projectionVersionUsed) {
    }

    private static final class CandidateAccumulator {
        private final String chunkId;
        private String content;
        private Double vectorScore;
        private Double keywordScore;
        private final Map<String, Object> metadata = new LinkedHashMap<>();

        private CandidateAccumulator(String chunkId) {
            this.chunkId = chunkId;
        }

        static CandidateAccumulator empty(String chunkId) {
            return new CandidateAccumulator(chunkId);
        }

        void mergeVector(String content, double vectorScore, Map<String, Object> metadata) {
            chooseContent(content);
            this.vectorScore = this.vectorScore == null ? vectorScore : Math.max(this.vectorScore, vectorScore);
            mergeMetadata(metadata);
        }

        void mergeKeyword(String content, double keywordScore, Map<String, Object> metadata) {
            chooseContent(content);
            this.keywordScore = this.keywordScore == null ? keywordScore : Math.max(this.keywordScore, keywordScore);
            mergeMetadata(metadata);
        }

        private void chooseContent(String incoming) {
            if (incoming == null || incoming.isBlank()) {
                return;
            }
            if (content == null || content.isBlank() || incoming.length() > content.length()) {
                content = incoming;
            }
        }

        private void mergeMetadata(Map<String, Object> incoming) {
            if (incoming == null || incoming.isEmpty()) {
                return;
            }
            incoming.forEach((key, value) -> {
                if (value != null) {
                    metadata.putIfAbsent(key, value);
                }
            });
        }

        double hybridScore() {
            return (vectorScore == null ? 0.0d : vectorScore)
                    + (keywordScore == null ? 0.0d : keywordScore * KEYWORD_WEIGHT);
        }

        String chunkId() {
            return chunkId;
        }

        String content() {
            return content == null ? "" : content;
        }

        Double vectorScore() {
            return vectorScore;
        }

        Double keywordScore() {
            return keywordScore;
        }

        Map<String, Object> metadata() {
            return metadata;
        }
    }
}
