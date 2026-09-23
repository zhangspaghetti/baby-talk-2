package com.zhangspaghetti.babytalk.practice.discovery.safety;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

class CustomSceneSafetyExecutorConfigurationTest {

    @Test
    void classifierExecutorIsBoundedWithRequiredPoolAndQueueSizes() {
        var executor = new CustomSceneSafetyExecutorConfiguration().customSceneSafetyExecutor();
        try {
            assertThat(executor).isInstanceOf(ThreadPoolTaskExecutor.class);
            assertThat(executor.getCorePoolSize()).isEqualTo(2);
            assertThat(executor.getMaxPoolSize()).isEqualTo(4);
            assertThat(executor.getThreadPoolExecutor().getQueue().remainingCapacity()).isEqualTo(16);
            assertThat(executor.getThreadNamePrefix()).contains("custom-scene-safety");
        } finally {
            executor.shutdown();
        }
    }
}
