package com.zhangspaghetti.babytalk.practice.agentic;

import com.openai.errors.OpenAIIoException;
import com.openai.errors.OpenAIServiceException;
import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.net.http.HttpTimeoutException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeoutException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiCallFailureClassifier {

    private static final int MAX_CAUSE_DEPTH = 32;

    public Optional<String> classify(Throwable failure) {
        if (failure instanceof OperationRequest.StagedProviderFailure stagedFailure
                && stagedFailure.failureStage()
                        == OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER) {
            return Optional.of("structured_output_invalid");
        }
        var causes = safeCauseChain(failure);
        for (var current : causes) {
            if (current instanceof PracticeAiStructuredOutputCaller.OutputBudgetTooSmallException) {
                return Optional.of("output_budget_too_small");
            }
            if (current instanceof PracticeAiStructuredOutputCaller.StructuredOutputInvalidException exception) {
                return Optional.of(exception.failureCode());
            }
            if (current instanceof SocketTimeoutException
                    || current instanceof HttpTimeoutException
                    || current instanceof TimeoutException) {
                return Optional.of("timeout");
            }
            if (current instanceof OpenAIServiceException serviceException) {
                if (serviceException.statusCode() == 429) {
                    return Optional.of("rate_limited");
                }
                if (serviceException.statusCode() >= 500) {
                    return Optional.of("server_error");
                }
            }
        }
        for (var current : causes) {
            if (current instanceof OpenAIIoException
                    || current instanceof ConnectException
                    || current instanceof UnknownHostException) {
                return Optional.of("connection_error");
            }
        }
        return Optional.empty();
    }

    private List<Throwable> safeCauseChain(Throwable failure) {
        var causes = new ArrayList<Throwable>();
        var visited = Collections.newSetFromMap(new IdentityHashMap<Throwable, Boolean>());
        Throwable current = failure;
        for (int depth = 0; current != null; depth++) {
            if (depth >= MAX_CAUSE_DEPTH || !visited.add(current)) {
                return List.of();
            }
            causes.add(current);
            try {
                current = current.getCause();
            } catch (Throwable causeInspectionFailure) {
                return List.of();
            }
        }
        return List.copyOf(causes);
    }
}
