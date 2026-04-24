package com.zhangspaghetti.babytalk.config;

import java.util.concurrent.Executor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * 异步执行配置 — 为文献 ingestion 管道提供有界线程池。
 */
@Configuration
@EnableAsync
public class AsyncConfiguration {

    private static final Logger log = LoggerFactory.getLogger(AsyncConfiguration.class);

    @Bean(name = "ingestionExecutor")
    public Executor ingestionExecutor() {
        log.info("初始化 ingestion 线程池: core=2, max=4, queue=50");

        var executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("ingestion-");
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}
