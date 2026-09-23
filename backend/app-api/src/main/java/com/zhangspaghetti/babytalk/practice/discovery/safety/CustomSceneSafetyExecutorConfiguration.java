package com.zhangspaghetti.babytalk.practice.discovery.safety;

import java.util.concurrent.ThreadPoolExecutor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration(proxyBeanMethods = false)
public class CustomSceneSafetyExecutorConfiguration {

    public static final String EXECUTOR_BEAN_NAME = "customSceneSafetyExecutor";
    public static final int CORE_POOL_SIZE = 2;
    public static final int MAX_POOL_SIZE = 4;
    public static final int QUEUE_CAPACITY = 16;

    @Bean(name = EXECUTOR_BEAN_NAME, destroyMethod = "shutdown")
    public ThreadPoolTaskExecutor customSceneSafetyExecutor() {
        var executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(CORE_POOL_SIZE);
        executor.setMaxPoolSize(MAX_POOL_SIZE);
        executor.setQueueCapacity(QUEUE_CAPACITY);
        executor.setThreadNamePrefix("custom-scene-safety-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.AbortPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(false);
        executor.setAwaitTerminationSeconds(1);
        executor.initialize();
        return executor;
    }

}
