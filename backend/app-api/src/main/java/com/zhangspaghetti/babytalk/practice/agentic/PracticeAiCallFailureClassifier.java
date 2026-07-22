package com.zhangspaghetti.babytalk.practice.agentic;

import com.openai.errors.OpenAIIoException;
import com.openai.errors.OpenAIServiceException;
import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.net.http.HttpTimeoutException;
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

    public Optional<String> classify(Throwable failure) {
        for (Throwable current = failure; current != null; current = current.getCause()) {
            if (current instanceof PracticeAiStructuredOutputCaller.StructuredOutputInvalidException) {
                return Optional.of("structured_output_invalid");
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
        for (Throwable current = failure; current != null; current = current.getCause()) {
            if (current instanceof OpenAIIoException
                    || current instanceof ConnectException
                    || current instanceof UnknownHostException) {
                return Optional.of("connection_error");
            }
        }
        return Optional.empty();
    }
}
