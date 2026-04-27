package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface ConversationSessionMapper {

    @Select("""
            SELECT \"timestamp\"
            FROM spring_ai_chat_memory
            WHERE conversation_id = #{conversationId}
            ORDER BY \"timestamp\" DESC
            LIMIT 1
            """)
    Instant findLastMessageTimestamp(@Param("conversationId") String conversationId);
}
