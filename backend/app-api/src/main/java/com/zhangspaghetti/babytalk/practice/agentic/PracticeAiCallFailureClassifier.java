package com.zhangspaghetti.babytalk.practice.agentic;

import com.openai.errors.OpenAIIoException;
import com.openai.errors.OpenAIServiceException;
import java.io.IOException;
import java.net.ConnectException;
import java.net.SocketTimeoutException;
import java.net.UnknownHostException;
import java.net.http.HttpTimeoutException;
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

    public String classify(Throwable failure) {
        for (Throwable current = failure; current != null; current = current.getCause()) {
            if (current instanceof PracticeAiStructuredOutputCaller.StructuredOutputInvalidException) {
                return "structured_output_invalid";
            }
            if (current instanceof SocketTimeoutException
                    || current instanceof HttpTimeoutException
                    || current instanceof TimeoutException) {
                return "timeout";
            }
            if (current instanceof OpenAIServiceException serviceException) {
                if (serviceException.statusCode() == 429) {
                    return "rate_limited";
                }
                if (serviceException.statusCode() >= 500) {
                    return "server_error";
                }
            }
        }
        for (Throwable current = failure; current != null; current = current.getCause()) {
            if (current instanceof OpenAIIoException
                    || current instanceof ConnectException
                    || current instanceof UnknownHostException
                    || current instanceof IOException) {
                return "connection_error";
            }
        }
        return "server_error";
    }
}
