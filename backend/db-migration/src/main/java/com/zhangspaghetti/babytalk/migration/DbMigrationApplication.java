package com.zhangspaghetti.babytalk.migration;

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

@SpringBootApplication
public class DbMigrationApplication {

    static final String EXPECTED_CURRENT_VERSION = "25";
    static final int EXPECTED_APPLIED_MIGRATION_COUNT = 24;

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
    ApplicationRunner migrationSummaryRunner(Flyway flyway) {
        return args -> {
            var info = flyway.info();
            MigrationInfo current = info.current();
            String currentVersion = current == null ? "<none>" : current.getVersion().getVersion();
            int appliedCount = info.applied().length;
            if (!EXPECTED_CURRENT_VERSION.equals(currentVersion)
                    || EXPECTED_APPLIED_MIGRATION_COUNT != appliedCount) {
                throw new IllegalStateException(String.format(
                        "db-migration finished with unexpected schema state. "
                                + "expected currentVersion=%s appliedCount=%d "
                                + "but got currentVersion=%s appliedCount=%d",
                        EXPECTED_CURRENT_VERSION,
                        EXPECTED_APPLIED_MIGRATION_COUNT,
                        currentVersion,
                        appliedCount));
            }
            log.info("db-migration completed successfully. currentVersion={}, appliedCount={}", currentVersion, appliedCount);
        };
    }

    private static String rootCauseMessage(Throwable throwable) {
        Throwable current = throwable;
        while (current.getCause() != null && current.getCause() != current) {
            current = current.getCause();
        }
        return current.getMessage() == null ? current.getClass().getSimpleName() : current.getMessage();
    }
}
