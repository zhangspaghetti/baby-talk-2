package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.time.OffsetDateTime;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface MyBatisOnboardingConversationStore extends OnboardingConversationStore {

    @Override
    @Select("""
            select conversation_id, installation_ref_hash, local_event_id, request_fingerprint,
                   registry_revision, care_entry_id, generation_namespace, generation_key,
                   generation_version, generation_facets_json::text as generation_facets_json, locale, time_band,
                   generated_content_id, utterance_id, english_text, chinese_text,
                   pronunciation_hint, audio_ref, status, expires_at, created_at, updated_at
              from guest_onboarding_conversations
             where installation_ref_hash = #{installationRefHash}
               and local_event_id = #{localEventId}
            """)
    StoredConversation find(
            @Param("installationRefHash") String installationRefHash,
            @Param("localEventId") String localEventId);

    @Override
    @Select("""
            select conversation_id, installation_ref_hash, local_event_id, request_fingerprint,
                   registry_revision, care_entry_id, generation_namespace, generation_key,
                   generation_version, generation_facets_json::text as generation_facets_json, locale, time_band,
                   generated_content_id, utterance_id, english_text, chinese_text,
                   pronunciation_hint, audio_ref, status, expires_at, created_at, updated_at
              from guest_onboarding_conversations
             where conversation_id = #{conversationId}
            """)
    StoredConversation findByConversationId(@Param("conversationId") String conversationId);

    @Override
    @Insert("""
            insert into guest_onboarding_conversations (
                conversation_id, installation_ref_hash, local_event_id, request_fingerprint,
                registry_revision, care_entry_id, generation_namespace, generation_key,
                generation_version, generation_facets_json, locale, time_band,
                generated_content_id, utterance_id, english_text, chinese_text,
                pronunciation_hint, audio_ref, status, source, expires_at, created_at, updated_at
            ) values (
                #{conversationId}, #{installationRefHash}, #{localEventId}, #{requestFingerprint},
                #{registryRevision}, #{careEntryId}, #{generationNamespace}, #{generationKey},
                #{generationVersion}, cast(#{generationFacetsJson} as jsonb), #{locale}, #{timeBand},
                null, null, null, null,
                null, null, 'generating', 'remote_generated',
                #{expiresAt}, #{createdAt}, #{updatedAt}
            )
            on conflict (installation_ref_hash, local_event_id) do nothing
            """)
    int reserve(StoredConversation conversation);

    @Override
    @Update("""
            update guest_onboarding_conversations
               set generated_content_id = #{generatedContentId},
                   utterance_id = #{utteranceId}, english_text = #{englishText},
                   chinese_text = #{chineseText}, pronunciation_hint = #{pronunciationHint},
                   audio_ref = #{audioRef}, status = 'active',
                   expires_at = #{expiresAt}, updated_at = #{updatedAt}
             where conversation_id = #{conversationId} and status = 'generating'
            """)
    int activate(
            @Param("conversationId") String conversationId,
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
            delete from guest_onboarding_conversations
             where conversation_id = #{conversationId} and status = 'generating'
            """)
    int deleteReservation(@Param("conversationId") String conversationId);

    @Override
    @Update("""
            update guest_onboarding_conversations
               set expires_at = #{expiresAt}, updated_at = #{updatedAt}
             where conversation_id = #{conversationId}
               and status = 'active'
               and expires_at > #{updatedAt}
            """)
    int extendExpiry(
            @Param("conversationId") String conversationId,
            @Param("expiresAt") OffsetDateTime expiresAt,
            @Param("updatedAt") OffsetDateTime updatedAt);

    @Override
    @Delete("""
            delete from guest_onboarding_conversations
             where conversation_id in (
                 select conversation_id
                   from guest_onboarding_conversations
                  where expires_at <= #{expiresAtOrBefore}
                  order by expires_at
                  limit #{limit}
             )
            """)
    int deleteExpired(
            @Param("expiresAtOrBefore") OffsetDateTime expiresAtOrBefore,
            @Param("limit") int limit);

    @Override
    @Delete("""
            delete from guest_onboarding_conversations
             where installation_ref_hash = #{installationRefHash}
               and local_event_id = #{localEventId}
               and expires_at <= #{expiresAtOrBefore}
            """)
    int deleteExpiredIdentity(
            @Param("installationRefHash") String installationRefHash,
            @Param("localEventId") String localEventId,
            @Param("expiresAtOrBefore") OffsetDateTime expiresAtOrBefore);
}
