package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.ai.chat.memory.repository.jdbc.JdbcChatMemoryRepository;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * 验证 ChatMemoryConfiguration 手动配置的三个 bean 正确创建，
 * 并验证 MessageWindowChatMemory 可执行 add + get 基本操作。
 */
@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.0.0",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev"
})
class ChatMemoryConfigurationTest extends AbstractIntegrationTest {

    @Autowired
    private JdbcChatMemoryRepository chatMemoryRepository;

    @Autowired
    private ChatMemory chatMemory;

    @Autowired
    private MessageChatMemoryAdvisor messageChatMemoryAdvisor;

    @Test
    void chatMemoryRepository_beanExists() {
        assertThat(chatMemoryRepository).isNotNull();
        assertThat(chatMemoryRepository).isInstanceOf(JdbcChatMemoryRepository.class);
    }

    @Test
    void chatMemory_beanExists() {
        assertThat(chatMemory).isNotNull();
        assertThat(chatMemory).isInstanceOf(MessageWindowChatMemory.class);
    }

    @Test
    void messageChatMemoryAdvisor_beanExists() {
        assertThat(messageChatMemoryAdvisor).isNotNull();
        assertThat(messageChatMemoryAdvisor).isInstanceOf(MessageChatMemoryAdvisor.class);
    }

    @Test
    void chatMemory_addAndGet_roundTrip() {
        String conversationId = "test-conv-" + System.currentTimeMillis();

        // 添加用户消息和助手回复
        chatMemory.add(conversationId, List.of(
                new UserMessage("你好，宝宝今天怎么样？"),
                new AssistantMessage("宝宝今天状态很好！")
        ));

        // 读取消息历史
        List<Message> messages = chatMemory.get(conversationId);

        assertThat(messages).isNotEmpty();
        assertThat(messages).hasSize(2);
        assertThat(messages.get(0)).isInstanceOf(UserMessage.class);
        assertThat(messages.get(0).getText()).isEqualTo("你好，宝宝今天怎么样？");
        assertThat(messages.get(1)).isInstanceOf(AssistantMessage.class);
        assertThat(messages.get(1).getText()).isEqualTo("宝宝今天状态很好！");
    }

    @Test
    void chatMemory_maxMessages_enforced() {
        String conversationId = "test-max-" + System.currentTimeMillis();

        // 添加超过 maxMessages(10) 的消息（12 条消息 = 6 轮对话）
        for (int i = 1; i <= 6; i++) {
            chatMemory.add(conversationId, List.of(
                    new UserMessage("用户消息 " + i),
                    new AssistantMessage("助手回复 " + i)
            ));
        }

        // 查询应该只返回最近 10 条消息（第 2-6 轮 = 10 条）
        List<Message> messages = chatMemory.get(conversationId);
        assertThat(messages).hasSizeLessThanOrEqualTo(10);

        // 最早的消息应该已被丢弃
        // 最后一条消息应该是最近添加的
        String lastMessageText = messages.get(messages.size() - 1).getText();
        assertThat(lastMessageText).isEqualTo("助手回复 6");
    }
}
