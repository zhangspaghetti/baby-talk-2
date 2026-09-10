package com.zhangspaghetti.babytalk.practice.generated.internal;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Method;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

class PracticeAiAuditPersistenceAdapterTest {

    @Test
    void everyAuditMutationCommitsInAnIndependentTransaction() {
        assertThat(PracticeAiAuditPersistenceAdapter.class.getDeclaredMethods())
                .filteredOn(method -> java.lang.reflect.Modifier.isPublic(method.getModifiers()))
                .allSatisfy(this::assertRequiresNew);
    }

    private void assertRequiresNew(Method method) {
        var transactional = method.getAnnotation(Transactional.class);
        assertThat(transactional)
                .as(method.getName() + " must be transactional")
                .isNotNull();
        assertThat(transactional.propagation())
                .as(method.getName() + " must commit before/after provider network work")
                .isEqualTo(Propagation.REQUIRES_NEW);
    }
}
