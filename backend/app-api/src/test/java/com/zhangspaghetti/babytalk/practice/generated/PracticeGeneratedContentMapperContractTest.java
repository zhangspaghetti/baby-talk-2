package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

class PracticeGeneratedContentMapperContractTest {

    @Test
    void generatedContentMapperDoesNotExposeGenericCrudMutations() {
        assertThat(BaseMapper.class.isAssignableFrom(PracticeGeneratedContentMapper.class))
                .isFalse();

        var declaredMethods = Stream.of(PracticeGeneratedContentMapper.class.getDeclaredMethods())
                .map(method -> method.getName())
                .collect(Collectors.toSet());

        assertThat(declaredMethods).doesNotContain(
                "insert", "update", "updateById", "delete", "deleteById");
        assertThat(declaredMethods).contains(
                "insertRow",
                "insertDraftIgnoringLiveConflict",
                "activateDraft",
                "rejectDraft",
                "expireDraft",
                "deleteExpiredInstallationRows");
    }
}
