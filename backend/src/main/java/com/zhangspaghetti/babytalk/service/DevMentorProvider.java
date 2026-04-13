package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import java.util.Locale;

public class DevMentorProvider implements MentorProvider {

    private final MentorProperties properties;

    public DevMentorProvider(MentorProperties properties) {
        this.properties = properties;
    }

    @Override
    public ProviderResponse respond(ProviderRequest request) {
        var normalizedPrompt = request.prompt() == null ? "" : request.prompt().trim();
        if (containsToken(normalizedPrompt, properties.simulateTimeoutToken())) {
            throw new ProviderTimeoutException("dev mentor provider 模拟 timeout。");
        }
        if (containsToken(normalizedPrompt, properties.simulateUnavailableToken())) {
            throw new ProviderUnavailableException("dev mentor provider 模拟 unavailable。");
        }
        if (containsToken(normalizedPrompt, properties.simulateMalformedToken())) {
            throw new ProviderMalformedResponseException("dev mentor provider 模拟 malformed response。");
        }

        var responseText = trimToMax(generateSafeResponse(normalizedPrompt), properties.responseMaxLength());
        if (responseText.isBlank()) {
            throw new ProviderMalformedResponseException("dev mentor provider 生成了空响应。");
        }
        return new ProviderResponse(responseText, summarize(responseText));
    }

    private String generateSafeResponse(String prompt) {
        var lowerPrompt = prompt.toLowerCase(Locale.ROOT);
        if (lowerPrompt.contains("哭") || lowerPrompt.contains("cry")) {
            return "先把语速放慢，只说一句：\"I'm here with you.\" 抱近一点，停半拍，再描述你看到的感受。";
        }
        if (lowerPrompt.contains("睡") || lowerPrompt.contains("sleep")) {
            return "先压低声音，说：\"It's time to rest. I'm right here.\" 只保留一条短句，重复两次就够了。";
        }
        if (lowerPrompt.contains("吃") || lowerPrompt.contains("meal") || lowerPrompt.contains("饭")) {
            return "先顺着眼前动作说：\"Let's take one small bite.\" 说完停一下，等宝宝的眼神或动作回应。";
        }
        return "先只描述眼前正在发生的一件事：\"I'm right here with you.\" 句子越短越稳，等宝宝回应后再补下一句。";
    }

    private boolean containsToken(String prompt, String token) {
        return token != null
                && !token.isBlank()
                && prompt.toLowerCase(Locale.ROOT).contains(token.toLowerCase(Locale.ROOT));
    }

    private String summarize(String value) {
        var compact = value.replaceAll("\\s+", " ").trim();
        if (compact.length() <= 80) {
            return compact;
        }
        return compact.substring(0, 80) + "…";
    }

    private String trimToMax(String value, int maxLength) {
        if (value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
