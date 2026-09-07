package com.zhangspaghetti.babytalk.practice.scene;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.classic.spi.IThrowableProxy;
import ch.qos.logback.core.read.ListAppender;
import java.time.OffsetDateTime;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;

class ScenePersonalizationContextLoggingPrivacyTest {

    private static final String SENSITIVE_FAILURE =
            "raw custom generation brief owner-acct-123 profile-456 phone 13800138000";

    @Test
    void aggregationFailureEmitsSafeDiagnosticWithoutRawContext() {
        var mapper = mock(ScenePersonalizationContextMapper.class);
        when(mapper.findWeeklyReactionCounts(
                "household-secret", "owner-secret", OffsetDateTime.parse("2026-09-07T00:00:00Z"),
                OffsetDateTime.parse("2026-09-09T00:00:00Z")))
                .thenThrow(new IllegalStateException(SENSITIVE_FAILURE));
        var service = new ScenePersonalizationContextService(mapper);
        var subject = new GenerationSubject(
                "actor-secret", "owner-secret", "profile-secret", 1, "小满",
                "m7_11", "calmer_care", "household-secret", "caregiver");
        var logger = (Logger) LoggerFactory.getLogger(ScenePersonalizationContextService.class);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);
        try {
            var context = service.build(
                    subject,
                    "zh-CN",
                    OffsetDateTime.parse("2026-09-09T00:00:00Z"));
            assertThat(context.recentPracticeCount()).isZero();
            assertThat(context.dominantReaction()).isNull();
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }

        assertThat(appender.list).isNotEmpty();
        assertThat(appender.list).allSatisfy(event -> {
            assertThat(event.getFormattedMessage()).isNotNull();
            assertThat(event.getMDCPropertyMap()).isNotNull();
        });
        var logs = appender.list.stream()
                .map(event -> event.getFormattedMessage()
                        + "|mdc=" + event.getMDCPropertyMap()
                        + "|throwable=" + throwableText(event.getThrowableProxy()))
                .collect(Collectors.joining("\n"));
        assertThat(logs)
                .contains("errorType=IllegalStateException")
                .doesNotContain(
                        SENSITIVE_FAILURE,
                        "actor-secret",
                        "owner-secret",
                        "profile-secret",
                        "household-secret",
                        "小满",
                        "ScenePersonalizationContext{");
    }

    private static String throwableText(IThrowableProxy throwable) {
        if (throwable == null) {
            return "";
        }
        return throwable.getClassName() + ":" + throwable.getMessage()
                + "|cause=" + throwableText(throwable.getCause());
    }
}
