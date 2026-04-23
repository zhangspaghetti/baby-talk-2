package com.zhangspaghetti.babytalk.config;

import java.util.concurrent.Executor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * 异步执行配置 — 为文献 ingestion 管道提供线程池。
 *
 * <p>线程池参数：
 * <ul>
 *   <li>corePoolSize=2 — 日常保持 2 线程处理 ingestion 任务</li>
 *   <li>maxPoolSize=4 — 批量导入时最多扩展到 4 线程</li>
 *   <li>queueCapacity=50 — 队列容量 50，超过时拒绝（CallerRunsPolicy 可选）</li>
 *   <li>threadNamePrefix="ingestion-" — 便于日志追踪异步任务</li>
 * </ul>
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
