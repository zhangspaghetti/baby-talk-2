package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiOperationRunner.ProvidersExhaustedException;
import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.agentic.config.QualityRubric;
import com.zhangspaghetti.babytalk.practice.discovery.CustomSceneGeneratedContentValidator;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.ContentConstraints;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratorRequest;
import com.zhangspaghetti.babytalk.practice.generated.CustomSceneQualityJudge.JudgeRequest;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.CompositeCustomSceneEvidenceRetriever;
import com.zhangspaghetti.babytalk.practice.generated.evidence.CustomSceneEvidenceRetriever;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceBundleFactory;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceRetrievalRequest;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSummary;
import com.zhangspaghetti.babytalk.practice.generated.evidence.FrozenEvidenceBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.RetrievalStatus;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import com.zhangspaghetti.babytalk.practice.generated.quality.DimensionResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.EvidenceGapCode;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputGateResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.GeneratedOutputViolationCode;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeDimension;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdict;
import com.zhangspaghetti.babytalk.practice.generated.quality.JudgeVerdictCalculator;
import com.zhangspaghetti.babytalk.practice.generated.quality.RepairDirective;
import com.zhangspaghetti.babytalk.practice.generated.quality.SuggestedJudgeResult;
import com.zhangspaghetti.babytalk.practice.generated.quality.TypedRepairPackage;
import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.EnumSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class CustomSceneGenerationOrchestrator {

    private static final Logger LOGGER = LoggerFactory.getLogger(CustomSceneGenerationOrchestrator.class);
    private static final Duration INSTALLATION_ACTIVE_RETENTION = Duration.ofDays(30);
    private static final Duration TERMINAL_RETENTION = Duration.ofDays(7);
    private static final String JUDGE_EVIDENCE_ACTION_INCONSISTENT = "judge_evidence_action_inconsistent";
    private static final String ERROR_GENERATION_INVALID_OUTPUT = "generation_invalid_output";
    private static final String ERROR_GENERATED_CONTENT_REJECTED = "generated_content_rejected";
    private static final String ERROR_GENERATION_UNAVAILABLE = "generation_unavailable";
    private static final String ERROR_GENERATION_TIMEOUT = "generation_timeout";
    private static final String ERROR_INSUFFICIENT_EVIDENCE = "insufficient_evidence";
    private static final int MAX_BRANCH_VIOLATION_DIAGNOSTICS = 78;

    private final PracticeGeneratedContentCommands commands;
    private final PracticeGeneratedContentQueryMapper queryMapper;
    private final CustomSceneGenerator generator;
    private final CustomSceneRepairer repairer;
    private final CustomSceneGeneratedContentValidator validator;
    private final CustomSceneQualityJudge judge;
    private final JudgeVerdictCalculator verdictCalculator;
    private final CustomSceneEvidenceRetriever retriever;
    private final EvidenceBundleFactory bundleFactory;
    private final GenerationAttemptAuditPort attemptAudit;
    private final PracticeGeneratedContentKeyFactory keyFactory;
    private final Clock clock;

    @Autowired
    public CustomSceneGenerationOrchestrator(
            PracticeGeneratedContentCommands commands,
            PracticeGeneratedContentQueryMapper queryMapper,
            CustomSceneGenerator generator,
            CustomSceneRepairer repairer,
            CustomSceneGeneratedContentValidator validator,
            CustomSceneQualityJudge judge,
            JudgeVerdictCalculator verdictCalculator,
            CompositeCustomSceneEvidenceRetriever retriever,
            EvidenceBundleFactory bundleFactory,
            GenerationAttemptAuditPort attemptAudit,
            PracticeGeneratedContentKeyFactory keyFactory
    ) {
        this(commands, queryMapper, generator, repairer, validator, judge, verdictCalculator,
                retriever, bundleFactory, attemptAudit, keyFactory, Clock.systemUTC());
    }

    CustomSceneGenerationOrchestrator(
            PracticeGeneratedContentCommands commands,
            PracticeGeneratedContentQueryMapper queryMapper,
            CustomSceneGenerator generator,
            CustomSceneRepairer repairer,
            CustomSceneGeneratedContentValidator validator,
            CustomSceneQualityJudge judge,
            JudgeVerdictCalculator verdictCalculator,
            CustomSceneEvidenceRetriever retriever,
            EvidenceBundleFactory bundleFactory,
            GenerationAttemptAuditPort attemptAudit,
            PracticeGeneratedContentKeyFactory keyFactory,
            Clock clock
    ) {
        this.commands = Objects.requireNonNull(commands, "commands");
        this.queryMapper = Objects.requireNonNull(queryMapper, "queryMapper");
        this.generator = Objects.requireNonNull(generator, "generator");
        this.repairer = Objects.requireNonNull(repairer, "repairer");
        this.validator = Objects.requireNonNull(validator, "validator");
        this.judge = Objects.requireNonNull(judge, "judge");
        this.verdictCalculator = Objects.requireNonNull(verdictCalculator, "verdictCalculator");
        this.retriever = Objects.requireNonNull(retriever, "retriever");
        this.bundleFactory = Objects.requireNonNull(bundleFactory, "bundleFactory");
        this.attemptAudit = Objects.requireNonNull(attemptAudit, "attemptAudit");
        this.keyFactory = Objects.requireNonNull(keyFactory, "keyFactory");
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    public PracticeGeneratedContentEntity execute(GenerationExecution execution) {
        validateExecution(execution);
        var reserved = execution.reservedContent();
        FrozenEvidenceBundle previousBundle = null;
        RepairContext repairContext = null;

        for (int attemptNumber = 1; attemptNumber <= reserved.generationAttemptLimit(); attemptNumber++) {
            var attemptId = UUID.randomUUID();
            var attemptType = attemptNumber == 1 ? "generator" : "repair";
            try {
                attemptAudit.startAttempt(new GenerationAttemptAuditPort.AttemptStarted(
                        attemptId, reserved.generatedContentId(), attemptNumber, attemptType, now()));
            } catch (RuntimeException exception) {
                LOGGER.error("Unable to start generation attempt audit (attemptNumber={}, attemptType={}, errorType={})",
                        attemptNumber, attemptType, exception.getClass().getSimpleName());
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            }

            var attemptCodes = new ArrayList<String>();
            var repairInputCodes = new ArrayList<String>();
            FrozenEvidenceBundle bundle;
            try {
                if (attemptNumber == 1) {
                    var retrieval = retriever.retrieve(new EvidenceRetrievalRequest(
                            reserved.normalizedSceneText(),
                            reserved.ageRange(),
                            reserved.parentGoal(),
                            execution.requiredEvidenceClaimTypes(),
                            UUID.randomUUID()));
                    if (retrieval.status() == RetrievalStatus.INSUFFICIENT) {
                        return insufficientEvidence(reserved, attemptId, attemptNumber, List.of());
                    }
                    bundle = bundleFactory.createInitial(reserved.generatedContentId(), attemptNumber, retrieval);
                } else {
                    var decision = evidenceDecision(execution, repairContext);
                    repairInputCodes.addAll(repairContext.violationCodes());
                    if (decision.inconsistent()) {
                        attemptCodes.add(JUDGE_EVIDENCE_ACTION_INCONSISTENT);
                        repairInputCodes.add(JUDGE_EVIDENCE_ACTION_INCONSISTENT);
                    }
                    if (decision.claimTypes().isEmpty()) {
                        bundle = bundleFactory.deriveReused(
                                reserved.generatedContentId(), attemptNumber, previousBundle);
                    } else {
                        bundle = bundleFactory.createRefreshed(
                                reserved.generatedContentId(),
                                attemptNumber,
                                new EvidenceRetrievalRequest(
                                        reserved.normalizedSceneText(),
                                        reserved.ageRange(),
                                        reserved.parentGoal(),
                                        decision.claimTypes(),
                                        UUID.randomUUID()));
                    }
                }
            } catch (IllegalStateException exception) {
                return insufficientEvidence(reserved, attemptId, attemptNumber, attemptCodes);
            } catch (RuntimeException exception) {
                complete(attemptId, attemptNumber, "evidence_failure", attemptCodes);
                return expire(reserved, ERROR_INSUFFICIENT_EVIDENCE, true);
            }

            GeneratedCareMomentBundle careMoment;
            if (attemptNumber == 1) {
                GenerationStartDecision startDecision;
                try {
                    startDecision = commands.startGeneration(
                            reserved.generatedContentId(),
                            execution.dailyQuotaFrom(),
                            execution.dailyGenerationLimit(),
                            now());
                } catch (RuntimeException exception) {
                    complete(attemptId, attemptNumber, "generation_start_failure", attemptCodes);
                    return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
                }
                if (startDecision == GenerationStartDecision.DAILY_LIMIT_EXCEEDED) {
                    complete(attemptId, attemptNumber, "generation_rate_limited", attemptCodes);
                    commands.expire(
                            reserved.generatedContentId(),
                            "generation_rate_limited",
                            true,
                            now(),
                            now().plus(TERMINAL_RETENTION));
                    throw new PracticeGenerationRateLimitExceededException(
                            "daily", execution.dailyGenerationLimit());
                }
                if (startDecision == GenerationStartDecision.NOT_LIVE) {
                    complete(attemptId, attemptNumber, "not_live", attemptCodes);
                    var winner = queryMapper.findByGeneratedContentId(reserved.generatedContentId());
                    if (winner != null && "active".equals(winner.status())) {
                        return winner;
                    }
                    throw new GenerationExecutionException("generation_not_live", true);
                }
            }
            try {
                if (attemptNumber == 1) {
                    var generatorRequest = new GeneratorRequest(
                            reserved.generatedContentId(),
                            attemptNumber,
                            reserved.normalizedSceneText(),
                            reserved.ageRange(),
                            reserved.parentGoal(),
                            reserved.locale(),
                            bundle,
                            execution.generationProfile(),
                            execution.contentConstraints());
                    careMoment = generator.generateCareMoment(generatorRequest);
                    if (careMoment == null) {
                        throw new GenerationExecutionException("complete_bundle_missing", false);
                    }
                } else {
                    careMoment = repairer.repairCareMoment(new CustomSceneRepairer.RepairRequest(
                            reserved.generatedContentId(),
                            attemptNumber,
                            bundle.evidenceBundleId(),
                            reserved.locale(),
                            repairPackage(execution, repairContext, bundle, repairInputCodes)));
                    if (careMoment == null) {
                        throw new GenerationExecutionException("complete_bundle_missing", false);
                    }
                }
            } catch (ProvidersExhaustedException exception) {
                complete(attemptId, attemptNumber, "providers_exhausted", attemptCodes);
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            } catch (CustomSceneGenerator.GenerationTimeoutException exception) {
                complete(attemptId, attemptNumber, ERROR_GENERATION_TIMEOUT, attemptCodes);
                return expire(reserved, ERROR_GENERATION_TIMEOUT, true);
            } catch (CustomSceneGenerator.GenerationUnavailableException exception) {
                complete(attemptId, attemptNumber, exception.reason(), attemptCodes);
                return expire(reserved, exception.reason(), exception.retryable());
            } catch (RuntimeException exception) {
                complete(attemptId, attemptNumber, "provider_failure", attemptCodes);
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            }

            BundleGateResult gate;
            try {
                gate = evaluateBundle(careMoment, execution.contentConstraints(), reserved.normalizedSceneText());
            } catch (RuntimeException exception) {
                complete(attemptId, attemptNumber, "validation_failure", attemptCodes);
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            }
            if (!gate.terminalViolations().isEmpty()) {
                var codes = combined(
                        attemptCodes,
                        combined(
                                violationCodes(gate.terminalViolations()),
                                gate.terminalViolationDiagnostics()));
                complete(attemptId, attemptNumber, "terminal_violation", codes);
                return reject(reserved, ERROR_GENERATION_INVALID_OUTPUT, false);
            }
            if (!gate.repairableViolations().isEmpty()) {
                var codes = combined(
                        attemptCodes,
                        combined(
                                violationCodes(gate.repairableViolations()),
                                gate.repairableViolationDiagnostics()));
                repairContext = deterministicRepairContext(gate.normalizedBundle(), gate.repairableViolations(), codes);
                if (attemptNumber == reserved.generationAttemptLimit()) {
                    complete(attemptId, attemptNumber, "attempt_limit_exhausted", codes);
                    return reject(reserved, repairableViolationErrorCode(gate.repairableViolations()), false);
                }
                if (!complete(attemptId, attemptNumber, "repairable_violation", codes)) {
                    return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
                }
                previousBundle = bundle;
                continue;
            }

            careMoment = gate.normalizedBundle();

            SuggestedJudgeResult suggested;
            com.zhangspaghetti.babytalk.practice.generated.quality.EffectiveJudgeResult effective;
            try {
                suggested = judge.judge(judgeRequest(execution, attemptNumber, bundle, careMoment));
                effective = verdictCalculator.calculate(suggested, execution.qualityRubric());
            } catch (ProvidersExhaustedException exception) {
                complete(attemptId, attemptNumber, "providers_exhausted", attemptCodes);
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            } catch (CustomSceneGenerator.GenerationUnavailableException exception) {
                complete(attemptId, attemptNumber, exception.reason(), attemptCodes);
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, exception.retryable());
            } catch (RuntimeException exception) {
                complete(attemptId, attemptNumber, "judge_failure", attemptCodes);
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            }
            var judgeCodes = combined(attemptCodes, suggested.violationCodes());
            if (effective.effectiveVerdict() == JudgeVerdict.PASS) {
                try {
                    return commands.activateWithCompletedAttempt(
                            activeRow(reserved, careMoment),
                            new GenerationAttemptAuditPort.AttemptCompleted(
                                    attemptId, attemptNumber, "passed", stableCodes(judgeCodes), now()))
                            .orElseThrow(() -> new GenerationExecutionException("activation_failure", true));
                } catch (RuntimeException exception) {
                    complete(attemptId, attemptNumber, "activation_failure", judgeCodes);
                    return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
                }
            }
            if (effective.effectiveVerdict() == JudgeVerdict.REJECT) {
                complete(attemptId, attemptNumber, "judge_reject", judgeCodes);
                return reject(reserved, ERROR_GENERATION_INVALID_OUTPUT, false);
            }

            repairContext = judgeRepairContext(careMoment, suggested, effective.effectiveVerdict(), judgeCodes);
            if (attemptNumber == reserved.generationAttemptLimit()) {
                complete(attemptId, attemptNumber, "attempt_limit_exhausted", judgeCodes);
                return reject(reserved, ERROR_GENERATION_INVALID_OUTPUT, false);
            }
            if (!complete(
                    attemptId,
                    attemptNumber,
                    effective.effectiveVerdict() == JudgeVerdict.ABSTAIN ? "judge_abstain" : "judge_repair",
                    judgeCodes)) {
                return expire(reserved, ERROR_GENERATION_UNAVAILABLE, true);
            }
            previousBundle = bundle;
        }
        throw new IllegalStateException("generation attempt loop exhausted without terminal state");
    }

    private PracticeGeneratedContentEntity insufficientEvidence(
            PracticeGeneratedContentEntity reserved,
            UUID attemptId,
            int attemptNumber,
            List<String> codes
    ) {
        complete(attemptId, attemptNumber, "insufficient_evidence", codes);
        return expire(reserved, ERROR_INSUFFICIENT_EVIDENCE, true);
    }

    private String repairableViolationErrorCode(List<GeneratedOutputViolationCode> violations) {
        return violations.contains(GeneratedOutputViolationCode.COURSE_OR_SCORING_FRAMING)
                ? ERROR_GENERATED_CONTENT_REJECTED
                : ERROR_GENERATION_INVALID_OUTPUT;
    }

    private TypedRepairPackage repairPackage(
            GenerationExecution execution,
            RepairContext context,
            FrozenEvidenceBundle bundle,
            List<String> repairInputCodes
    ) {
        return new TypedRepairPackage(
                execution.reservedContent().normalizedSceneText(),
                execution.reservedContent().ageRange(),
                execution.reservedContent().parentGoal(),
                context.previousBundle().completeBundle(),
                context.effectiveVerdict(),
                context.failedDimensions(),
                stableCodes(repairInputCodes),
                context.repairDirectives(),
                bundle.items().stream()
                        .map(item -> new EvidenceSummary(item.sanitizedSummary(), item.sanitizedSummaryHash()))
                        .toList(),
                execution.generationProfile());
    }

    private JudgeRequest judgeRequest(
            GenerationExecution execution,
            int attemptNumber,
            FrozenEvidenceBundle bundle,
            GeneratedCareMomentBundle careMoment
    ) {
        var reserved = execution.reservedContent();
        var strategies = bundle.items().stream()
                .map(item -> item.strategyId())
                .filter(value -> value != null && !value.isBlank())
                .distinct()
                .sorted()
                .toList();
        var safetyTags = execution.generationProfile().contentSafetyPolicyVersion() == null
                || execution.generationProfile().contentSafetyPolicyVersion().isBlank()
                ? List.<String>of()
                : List.of(execution.generationProfile().contentSafetyPolicyVersion());
        return new JudgeRequest(
                reserved.generatedContentId(),
                attemptNumber,
                bundle.evidenceBundleId(),
                reserved.normalizedSceneText(),
                reserved.ageRange(),
                reserved.parentGoal(),
                careMoment.starter(),
                careMoment,
                strategies,
                List.of(),
                List.of(),
                safetyTags,
                bundle.items().stream().map(item -> item.sanitizedSummary()).toList(),
                execution.qualityRubric().version(),
                execution.qualityRubric().contentHash());
    }

    private BundleGateResult evaluateBundle(
            GeneratedCareMomentBundle bundle,
            CustomSceneGenerator.ContentConstraints constraints,
            String normalizedSceneText
    ) {
        var terminal = new ArrayList<GeneratedOutputViolationCode>();
        var repairable = new ArrayList<GeneratedOutputViolationCode>();
        var terminalDiagnostics = new ArrayList<String>();
        var repairableDiagnostics = new ArrayList<String>();
        var branches = bundle.completeBundle().utterances().stream()
                .map(this::safeBranchName)
                .iterator();
        var normalized = bundle.mapCandidates(candidate -> {
            if (!branches.hasNext()) {
                throw new IllegalStateException("bundle validation exceeded canonical branch count");
            }
            var branch = branches.next();
            var result = validator.evaluate(
                    candidate,
                    constraints,
                    new CustomSceneGeneratedContentValidator.GeneratedOutputValidationContext(normalizedSceneText));
            terminal.addAll(result.terminalViolations());
            repairable.addAll(result.repairableViolations());
            terminalDiagnostics.addAll(branchDiagnostics(branch, result.terminalViolations()));
            repairableDiagnostics.addAll(branchDiagnostics(branch, result.repairableViolations()));
            return result.normalizedCandidate();
        });
        if (branches.hasNext()) {
            throw new IllegalStateException("bundle validation did not consume every canonical branch");
        }
        return new BundleGateResult(
                normalized,
                terminal.stream().distinct().sorted().toList(),
                repairable.stream().distinct().sorted().toList(),
                boundedDiagnostics(terminalDiagnostics),
                boundedDiagnostics(repairableDiagnostics));
    }

    private List<String> branchDiagnostics(
            String branch,
            List<GeneratedOutputViolationCode> violations
    ) {
        return violations.stream()
                .map(this::safeViolationCode)
                .distinct()
                .sorted()
                .map(code -> branch + ":" + code)
                .toList();
    }

    private List<String> boundedDiagnostics(List<String> diagnostics) {
        var stable = stableCodes(diagnostics);
        if (stable.size() > MAX_BRANCH_VIOLATION_DIAGNOSTICS) {
            throw new IllegalStateException("bundle validation diagnostics exceeded fixed bound");
        }
        return stable;
    }

    private String safeBranchName(CompleteGeneratedBundle.Utterance utterance) {
        return switch (utterance.role()) {
            case STARTER -> {
                if (utterance.reaction() != null) {
                    throw new IllegalStateException("starter branch cannot have a reaction");
                }
                yield "starter";
            }
            case REACTION_SUPPORT -> switch (Objects.requireNonNull(
                    utterance.reaction(), "reaction support branch reaction")) {
                case COOPERATING -> "cooperating";
                case HESITANT -> "hesitant";
                case RESISTING -> "resisting";
                case NO_RESPONSE -> "no_response";
                case OTHER -> "other";
            };
        };
    }

    private RepairContext deterministicRepairContext(
            GeneratedCareMomentBundle bundle,
            List<GeneratedOutputViolationCode> violations,
            List<String> codes
    ) {
        var dimensions = EnumSet.noneOf(JudgeDimension.class);
        var directives = EnumSet.noneOf(RepairDirective.class);
        for (var violation : violations) {
            switch (violation) {
                case MISSING_TPR_ACTION -> {
                    dimensions.add(JudgeDimension.TPR_QUALITY);
                    directives.add(RepairDirective.REPAIR_TPR_QUALITY);
                }
                case MISSING_DELIVERY_GUIDANCE -> {
                    dimensions.add(JudgeDimension.DELIVERY_GUIDANCE_QUALITY);
                    directives.add(RepairDirective.REPAIR_DELIVERY_GUIDANCE_QUALITY);
                }
                case FIELD_ROLE_MISMATCH -> {
                    dimensions.add(JudgeDimension.TPR_QUALITY);
                    dimensions.add(JudgeDimension.DELIVERY_GUIDANCE_QUALITY);
                    directives.add(RepairDirective.REPAIR_TPR_QUALITY);
                    directives.add(RepairDirective.REPAIR_DELIVERY_GUIDANCE_QUALITY);
                }
                case META_INSTRUCTION, COURSE_OR_SCORING_FRAMING, MARKDOWN_OR_TEMPLATE -> {
                    dimensions.add(JudgeDimension.NON_COURSE_FRAMING);
                    directives.add(RepairDirective.REPAIR_NON_COURSE_FRAMING);
                }
                default -> throw new IllegalArgumentException("terminal violation cannot create repair context");
            }
        }
        return new RepairContext(
                bundle,
                JudgeVerdict.REPAIR,
                List.copyOf(dimensions),
                codes,
                List.copyOf(directives),
                List.of());
    }

    private RepairContext judgeRepairContext(
            GeneratedCareMomentBundle bundle,
            SuggestedJudgeResult suggested,
            JudgeVerdict effectiveVerdict,
            List<String> codes
    ) {
        var failed = suggested.dimensionResults().entrySet().stream()
                .filter(entry -> entry.getValue() != DimensionResult.PASS)
                .map(java.util.Map.Entry::getKey)
                .sorted()
                .toList();
        return new RepairContext(
                bundle,
                effectiveVerdict,
                failed,
                codes,
                suggested.repairDirectives(),
                suggested.evidenceGapCodes());
    }

    private EvidenceDecision evidenceDecision(GenerationExecution execution, RepairContext context) {
        var claims = new LinkedHashSet<String>();
        boolean inconsistent = false;
        for (var gap : context.evidenceGapCodes()) {
            var claim = switch (gap) {
                case SCENE_ALIGNMENT_EVIDENCE_MISSING -> "scene_support";
                case PARENT_SPEAKABILITY_EVIDENCE_MISSING -> "parent_speakability";
                case AGE_SUITABILITY_EVIDENCE_MISSING -> "age_guidance";
                case LOW_PRESSURE_SUPPORT_EVIDENCE_MISSING -> "low_pressure_delivery";
                default -> null;
            };
            if (claim == null || !execution.requiredEvidenceClaimTypes().contains(claim)) {
                inconsistent = true;
            } else {
                claims.add(claim);
            }
        }
        return new EvidenceDecision(Set.copyOf(claims), inconsistent);
    }

    private PracticeGeneratedContentEntity activeRow(
            PracticeGeneratedContentEntity draft,
            GeneratedCareMomentBundle careMoment
    ) {
        var candidate = careMoment.starter();
        var slugHash = keyFactory.stableDigest(
                draft.ownerKey() + "|" + draft.requestFingerprint() + "|"
                        + draft.generationProfileVersion() + "|" + draft.evidencePolicyVersion() + "|"
                        + draft.generatedContentId());
        var active = new PracticeGeneratedContentEntity();
        active.setGeneratedContentId(draft.generatedContentId());
        active.setOwnerScope(draft.ownerScope());
        active.setOwnerKey(draft.ownerKey());
        active.setOwnerKeyVersion(draft.ownerKeyVersion());
        active.setAccountId(draft.accountId());
        active.setInstallationRefHash(draft.installationRefHash());
        active.setProfileId(draft.profileId());
        active.setSurface(draft.surface());
        active.setMode(draft.mode());
        active.setRequestFingerprint(draft.requestFingerprint());
        active.setAgeRange(draft.ageRange());
        active.setParentGoal(draft.parentGoal());
        active.setLocale(draft.locale());
        active.setSpaceSlug("gen_scene_" + slugHash.substring(0, 20));
        active.setActivitySlug("gen_activity_" + slugHash.substring(20, 40));
        active.setPhraseSlug("gen_phrase_" + slugHash.substring(40, 60));
        active.setSpaceTitleZh(candidate.spaceTitleZh());
        active.setActivityTitleZh(candidate.activityTitleZh());
        active.setSceneTagEn(candidate.sceneTagEn());
        active.setTprActionZh(candidate.tprActionZh());
        active.setDeliveryGuidanceZh(candidate.deliveryGuidanceZh());
        active.setEnglishText(candidate.englishText());
        active.setChineseText(candidate.chineseText());
        active.setPronunciationHint(candidate.pronunciationHint());
        active.setDifficulty(candidate.difficulty());
        active.setGenerationSource(candidate.generationSource());
        active.setStatus("active");
        active.setGenerationProfileVersion(draft.generationProfileVersion());
        active.setGenerationProfileHash(draft.generationProfileHash());
        active.setRubricVersion(draft.rubricVersion());
        active.setRubricContentHash(draft.rubricContentHash());
        active.setEvidencePolicyVersion(draft.evidencePolicyVersion());
        active.setEvidencePolicyContentHash(draft.evidencePolicyContentHash());
        active.setProviderRoutingPolicyVersion(draft.providerRoutingPolicyVersion());
        active.setProviderRoutingPolicyHash(draft.providerRoutingPolicyHash());
        active.setGenerationAttemptLimit(draft.generationAttemptLimit());
        active.setContentRefreshEpoch(draft.contentRefreshEpoch());
        active.setContentVersion(draft.contentVersion());
        active.setRetentionExpiresAt("installation".equals(draft.ownerScope())
                ? now().plus(INSTALLATION_ACTIVE_RETENTION)
                : null);
        active.setCreatedAt(draft.createdAt());
        active.setUpdatedAt(now());
        active.setApprovedUtterances(toApprovedUtterances(active, careMoment));
        return active;
    }

    private List<com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity>
    toApprovedUtterances(PracticeGeneratedContentEntity active, GeneratedCareMomentBundle careMoment) {
        var rows = new ArrayList<com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity>();
        rows.add(utterance(active, "starter", null, 1, careMoment.starterUtterance()));
        for (var reaction : GeneratedCareMomentBundle.ReactionType.values()) {
            rows.add(utterance(active, "reaction_support", reaction.wireValue(), reaction.ordinal() + 2,
                    careMoment.reactionSupports().get(reaction)));
        }
        return List.copyOf(rows);
    }

    private com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity utterance(
            PracticeGeneratedContentEntity active,
            String role,
            String reactionType,
            int displayOrder,
            GeneratedCareUtterance content
    ) {
        var row = new com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentUtteranceEntity();
        var identity = active.generatedContentId() + "|" + role + "|" + (reactionType == null ? "starter" : reactionType);
        row.setUtteranceId("starter".equals(role)
                ? active.phraseSlug()
                : "gen_utt_" + keyFactory.stableDigest(identity).substring(0, 48));
        row.setGeneratedContentId(active.generatedContentId());
        row.setRole(role);
        row.setReactionType(reactionType);
        row.setEnglishText(content.englishText());
        row.setChineseText(content.chineseText());
        row.setPronunciationHint(content.pronunciationHint());
        row.setTprActionZh(content.tprActionZh());
        row.setDeliveryGuidanceZh(content.deliveryGuidanceZh());
        row.setDifficulty(content.difficulty());
        row.setDisplayOrder(displayOrder);
        row.setApprovalStatus("approved");
        row.setApprovedContentVersion(active.contentVersion());
        row.setBundleSchemaVersion(
                com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle.CURRENT_SCHEMA_VERSION);
        row.setProviderOrigin(content.providerProvenance().origin().wireValue());
        row.setProviderName(content.providerProvenance().providerName());
        row.setProviderModelName(content.providerProvenance().modelName());
        row.setProviderAttemptNumber(content.providerProvenance().attemptNumber());
        row.setCreatedAt(active.updatedAt());
        return row;
    }

    private PracticeGeneratedContentEntity reject(
            PracticeGeneratedContentEntity reserved,
            String code,
            boolean retryable
    ) {
        commands.reject(
                reserved.generatedContentId(), code, retryable, now(), now().plus(TERMINAL_RETENTION));
        return loadTerminal(reserved.generatedContentId(), "rejected");
    }

    private PracticeGeneratedContentEntity expire(
            PracticeGeneratedContentEntity reserved,
            String code,
            boolean retryable
    ) {
        commands.expire(
                reserved.generatedContentId(), code, retryable, now(), now().plus(TERMINAL_RETENTION));
        return loadTerminal(reserved.generatedContentId(), "expired");
    }

    private PracticeGeneratedContentEntity loadTerminal(String generatedContentId, String expectedStatus) {
        var loaded = queryMapper.findByGeneratedContentId(generatedContentId);
        if (loaded == null || !expectedStatus.equals(loaded.status())) {
            throw new GenerationExecutionException("terminal_transition_failure", true);
        }
        return loaded;
    }

    private boolean complete(UUID attemptId, int attemptNumber, String outcome, List<String> codes) {
        try {
            attemptAudit.completeAttempt(new GenerationAttemptAuditPort.AttemptCompleted(
                    attemptId, attemptNumber, outcome, stableCodes(codes), now()));
            return true;
        } catch (RuntimeException exception) {
            LOGGER.error("Unable to complete generation attempt audit (attemptNumber={}, outcome={}, errorType={})",
                    attemptNumber, outcome, exception.getClass().getSimpleName());
            return false;
        }
    }

    private List<String> violationCodes(List<GeneratedOutputViolationCode> violations) {
        return violations.stream().map(this::safeViolationCode).toList();
    }

    private String safeViolationCode(GeneratedOutputViolationCode violation) {
        Objects.requireNonNull(violation, "generated output violation");
        return switch (violation) {
            case OUTPUT_PII,
                    OUTPUT_BIDI_CONTROL,
                    OUTPUT_ADULT_VIOLENT,
                    OUTPUT_DANGEROUS_MEDICAL,
                    UNTRUSTED_METADATA,
                    DATABASE_OVERFLOW,
                    INVALID_ENUM,
                    MISSING_TPR_ACTION,
                    MISSING_DELIVERY_GUIDANCE,
                    FIELD_ROLE_MISMATCH,
                    META_INSTRUCTION,
                    COURSE_OR_SCORING_FRAMING,
                    MARKDOWN_OR_TEMPLATE -> violation.name();
        };
    }

    private List<String> combined(List<String> first, List<String> second) {
        var values = new ArrayList<String>(first.size() + second.size());
        values.addAll(first);
        values.addAll(second);
        return stableCodes(values);
    }

    private List<String> stableCodes(List<String> values) {
        return values.stream()
                .filter(Objects::nonNull)
                .distinct()
                .sorted(Comparator.naturalOrder())
                .toList();
    }

    private void validateExecution(GenerationExecution execution) {
        Objects.requireNonNull(execution, "execution");
        var reserved = execution.reservedContent();
        var profile = execution.generationProfile();
        var rubric = execution.qualityRubric();
        if (reserved.generationAttemptLimit() < 1 || reserved.generationAttemptLimit() > 5
                || !reserved.generationProfileVersion().equals(profile.version())
                || !reserved.generationProfileHash().equals(profile.contentHash())
                || !reserved.rubricVersion().equals(rubric.version())
                || !reserved.rubricContentHash().equals(rubric.contentHash())
                || !profile.rubric().version().equals(rubric.version())
                || !profile.rubric().contentHash().equals(rubric.contentHash())
                || !reserved.evidencePolicyVersion().equals(profile.evidencePolicy().version())
                || !reserved.evidencePolicyContentHash().equals(profile.evidencePolicy().contentHash())) {
            throw new IllegalArgumentException("generation execution lineage must match reserved snapshot");
        }
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
    }

    public record GenerationExecution(
            PracticeGeneratedContentEntity reservedContent,
            OffsetDateTime dailyQuotaFrom,
            int dailyGenerationLimit,
            GenerationProfile generationProfile,
            QualityRubric qualityRubric,
            Set<String> requiredEvidenceClaimTypes,
            ContentConstraints contentConstraints
    ) {
        public GenerationExecution {
            Objects.requireNonNull(reservedContent, "reservedContent");
            Objects.requireNonNull(dailyQuotaFrom, "dailyQuotaFrom");
            if (dailyGenerationLimit < 1) {
                throw new IllegalArgumentException("dailyGenerationLimit must be positive");
            }
            Objects.requireNonNull(generationProfile, "generationProfile");
            Objects.requireNonNull(qualityRubric, "qualityRubric");
            requiredEvidenceClaimTypes = Set.copyOf(
                    Objects.requireNonNull(requiredEvidenceClaimTypes, "requiredEvidenceClaimTypes"));
            Objects.requireNonNull(contentConstraints, "contentConstraints");
        }
    }

    public static final class GenerationExecutionException extends RuntimeException {
        private final String code;
        private final boolean retryable;

        public GenerationExecutionException(String code, boolean retryable) {
            super(code);
            this.code = code;
            this.retryable = retryable;
        }

        public String code() {
            return code;
        }

        public boolean retryable() {
            return retryable;
        }
    }

    private record RepairContext(
            GeneratedCareMomentBundle previousBundle,
            JudgeVerdict effectiveVerdict,
            List<JudgeDimension> failedDimensions,
            List<String> violationCodes,
            List<RepairDirective> repairDirectives,
            List<EvidenceGapCode> evidenceGapCodes
    ) {
    }

    private record BundleGateResult(
            GeneratedCareMomentBundle normalizedBundle,
            List<GeneratedOutputViolationCode> terminalViolations,
            List<GeneratedOutputViolationCode> repairableViolations,
            List<String> terminalViolationDiagnostics,
            List<String> repairableViolationDiagnostics
    ) {
    }

    private record EvidenceDecision(Set<String> claimTypes, boolean inconsistent) {
    }
}
