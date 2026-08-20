package com.zhangspaghetti.babytalk.migration;

import java.util.Objects;
import java.util.regex.Pattern;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.beans.factory.annotation.Value;

@SpringBootApplication
public class DbMigrationApplication {

    static final String EXPECTED_CURRENT_VERSION = "35";
    static final int EXPECTED_APPLIED_MIGRATION_COUNT = 34;
    private static final Pattern SAFE_CANDIDATE_ID = Pattern.compile("^[a-z0-9][a-z0-9._-]{2,127}$");
    private static final Pattern SAFE_MIGRATION_VERSION = Pattern.compile("^[0-9]+(?:_[0-9]+)?$");

    private static final Logger log = LoggerFactory.getLogger(DbMigrationApplication.class);

    public static void main(String[] args) {
        try {
            ConfigurableApplicationContext context = new SpringApplicationBuilder(DbMigrationApplication.class)
                    .web(WebApplicationType.NONE)
                    .run(args);
            int exitCode = SpringApplication.exit(context);
            log.info("db-migration exiting with code {}", exitCode);
            System.exit(exitCode);
        } catch (Exception ex) {
            log.error("db-migration failed before exit: {}", rootCauseMessage(ex), ex);
            System.exit(1);
        }
    }

    @Bean
    ApplicationRunner migrationSummaryRunner(
            Flyway flyway,
            @Value("${babytalk.candidate.id}") String candidateId,
            @Value("${babytalk.candidate.required-migration-version}") String requiredMigrationVersion
    ) {
        var normalizedCandidateId = require(candidateId, "babytalk.candidate.id", SAFE_CANDIDATE_ID,
                "must be a safe immutable candidate identifier");
        var normalizedMigrationVersion = require(requiredMigrationVersion,
                "babytalk.candidate.required-migration-version", SAFE_MIGRATION_VERSION,
                "must be a Flyway version");
        return args -> {
            var info = flyway.info();
            MigrationInfo current = info.current();
            String currentVersion = current == null ? "<none>" : current.getVersion().getVersion();
            int appliedCount = info.applied().length;
            if (!normalizedMigrationVersion.equals(currentVersion)) {
                throw new IllegalStateException(String.format(
                        "db-migration candidate %s requires currentVersion=%s but got currentVersion=%s "
                        + "with appliedCount=%d",
                        normalizedCandidateId,
                        normalizedMigrationVersion,
                        currentVersion,
                        appliedCount));
            }
            log.info("db-migration completed successfully. candidateId={}, currentVersion={}, appliedCount={}",
                    normalizedCandidateId, currentVersion, appliedCount);
        };
    }

    private static String require(
            String value,
            String property,
            Pattern pattern,
            String constraint
    ) {
        var normalized = Objects.requireNonNullElse(value, "").trim();
        if (normalized.isEmpty()) {
            throw new IllegalStateException(property + " is required");
        }
        if (!pattern.matcher(normalized).matches()) {
            throw new IllegalStateException(property + " " + constraint);
        }
        return normalized;
    }

    private static String rootCauseMessage(Throwable throwable) {
        Throwable current = throwable;
        while (current.getCause() != null && current.getCause() != current) {
            current = current.getCause();
        }
        return current.getMessage() == null ? current.getClass().getSimpleName() : current.getMessage();
    }
}
