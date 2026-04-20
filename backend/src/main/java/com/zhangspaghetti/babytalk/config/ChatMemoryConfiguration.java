package com.zhangspaghetti.babytalk.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.ai.chat.memory.repository.jdbc.JdbcChatMemoryRepository;
import org.springframework.ai.chat.memory.repository.jdbc.PostgresChatMemoryRepositoryDialect;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 手动配置 ChatMemory 基础设施（JdbcChatMemoryRepository + MessageWindowChatMemory + MessageChatMemoryAdvisor）。
 * <p>
 * 所有 Spring AI 自动配置已排除（ChatMemoryAutoConfiguration、JdbcChatMemoryRepositoryAutoConfiguration），
 * Flyway V13 负责建表，initialize-schema 设为 never 避免冲突。
 * <p>
 * maxMessages=10：保留最近 10 轮对话消息，超出自动丢弃最早的消息。
 */
@Configuration
public class ChatMemoryConfiguration {

    private static final Logger log = LoggerFactory.getLogger(ChatMemoryConfiguration.class);

    @Bean
    public JdbcChatMemoryRepository chatMemoryRepository(JdbcTemplate jdbcTemplate) {
        log.info("初始化 JdbcChatMemoryRepository: dialect=PostgresChatMemoryRepositoryDialect");
        return JdbcChatMemoryRepository.builder()
                .jdbcTemplate(jdbcTemplate)
                .dialect(new PostgresChatMemoryRepositoryDialect())
                .build();
    }

    @Bean
    public ChatMemory chatMemory(JdbcChatMemoryRepository chatMemoryRepository) {
        log.info("初始化 MessageWindowChatMemory: maxMessages=10");
        return MessageWindowChatMemory.builder()
                .chatMemoryRepository(chatMemoryRepository)
                .maxMessages(10)
                .build();
    }

    @Bean
    public MessageChatMemoryAdvisor messageChatMemoryAdvisor(ChatMemory chatMemory) {
        log.info("初始化 MessageChatMemoryAdvisor");
        return MessageChatMemoryAdvisor.builder(chatMemory).build();
    }
}
