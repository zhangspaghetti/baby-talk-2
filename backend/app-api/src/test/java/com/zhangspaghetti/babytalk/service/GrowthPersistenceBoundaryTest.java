package com.zhangspaghetti.babytalk.service;

import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.Arrays;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcOperations;

class GrowthPersistenceBoundaryTest {

    @Test
    void growthServicesDelegatePersistenceInsteadOfDependingOnJdbcOperations() {
        assertAll(
                () -> assertNoJdbcOperationsDependency(GardenFertilizerService.class),
                () -> assertNoJdbcOperationsDependency(GardenSnapshotService.class),
                () -> assertNoJdbcOperationsDependency(GrowthInsightsService.class),
                () -> assertNoJdbcOperationsDependency(GrowthSummaryService.class)
        );
    }

    private static void assertNoJdbcOperationsDependency(Class<?> serviceType) {
        boolean hasJdbcDependency = Arrays.stream(serviceType.getDeclaredFields())
                        .anyMatch(field -> JdbcOperations.class.isAssignableFrom(field.getType()))
                || Arrays.stream(serviceType.getDeclaredConstructors())
                        .flatMap(constructor -> Arrays.stream(constructor.getParameterTypes()))
                        .anyMatch(JdbcOperations.class::isAssignableFrom);

        assertFalse(
                hasJdbcDependency,
                () -> serviceType.getSimpleName() + " must delegate persistence to a mapper"
        );
    }
}
