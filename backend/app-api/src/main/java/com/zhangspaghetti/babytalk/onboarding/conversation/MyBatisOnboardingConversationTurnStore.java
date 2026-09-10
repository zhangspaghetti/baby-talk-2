package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.time.OffsetDateTime;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface MyBatisOnboardingConversationTurnStore extends OnboardingConversationTurnStore {

    @Override
    @Select("""
            select turn_id, conversation_id, local_event_id, request_fingerprint,
                   previous_utterance_id, parent_action, reaction_provided, reaction,
                   generated_content_id, utterance_id, english_text, chinese_text,
                   pronunciation_hint, audio_ref, status, expires_at, created_at, updated_at
              from guest_onboarding_conversation_turns
             where conversation_id = #{conversationId} and local_event_id = #{localEventId}
            """)
    StoredTurn find(
            @Param("conversationId") String conversationId,
            @Param("localEventId") String localEventId);

    @Override
    @Select("""
            select turn_id, conversation_id, local_event_id, request_fingerprint,
                   previous_utterance_id, parent_action, reaction_provided, reaction,
                   generated_content_id, utterance_id, english_text, chinese_text,
                   pronunciation_hint, audio_ref, status, expires_at, created_at, updated_at
              from guest_onboarding_conversation_turns
             where conversation_id = #{conversationId} and utterance_id = #{utteranceId}
               and status = 'active'
            """)
    StoredTurn findByUtterance(
            @Param("conversationId") String conversationId,
            @Param("utteranceId") String utteranceId);

    @Override
    @Insert("""
            insert into guest_onboarding_conversation_turns (
                turn_id, conversation_id, local_event_id, request_fingerprint,
                previous_utterance_id, parent_action, reaction_provided, reaction,
                status, expires_at, created_at, updated_at
            ) values (
                #{turnId}, #{conversationId}, #{localEventId}, #{requestFingerprint},
                #{previousUtteranceId}, #{parentAction}, #{reactionProvided}, #{reaction},
                'generating', #{expiresAt}, #{createdAt}, #{updatedAt}
            )
            on conflict (conversation_id, local_event_id) do nothing
            """)
    int reserve(StoredTurn turn);

    @Override
    @Update("""
            update guest_onboarding_conversation_turns
               set generated_content_id = #{generatedContentId}, utterance_id = #{utteranceId},
                   english_text = #{englishText}, chinese_text = #{chineseText},
                   pronunciation_hint = #{pronunciationHint}, audio_ref = #{audioRef},
                   status = 'active', expires_at = #{expiresAt}, updated_at = #{updatedAt}
             where turn_id = #{turnId} and status = 'generating'
            """)
    int activate(
            @Param("turnId") String turnId,
            @Param("generatedContentId") String generatedContentId,
            @Param("utteranceId") String utteranceId,
            @Param("englishText") String englishText,
            @Param("chineseText") String chineseText,
            @Param("pronunciationHint") String pronunciationHint,
            @Param("audioRef") String audioRef,
            @Param("expiresAt") OffsetDateTime expiresAt,
            @Param("updatedAt") OffsetDateTime updatedAt);

    @Override
    @Delete("""
            delete from guest_onboarding_conversation_turns
             where turn_id = #{turnId} and status = 'generating'
            """)
    int deleteReservation(@Param("turnId") String turnId);

    @Override
    @Delete("""
            delete from guest_onboarding_conversation_turns
             where conversation_id = #{conversationId}
               and local_event_id = #{localEventId}
               and status = 'generating'
               and expires_at <= #{expiresAtOrBefore}
            """)
    int deleteExpiredReservation(
            @Param("conversationId") String conversationId,
            @Param("localEventId") String localEventId,
            @Param("expiresAtOrBefore") OffsetDateTime expiresAtOrBefore);
}
