alter table guest_onboarding_conversations
    add column installation_owner_key varchar(80);

-- Preserve active V32 conversations by recovering the same opaque owner key
-- from the generated content that produced their first utterance. Requiring
-- the installation reference match prevents a content-id mix-up from changing
-- conversation ownership.
update guest_onboarding_conversations conversation
   set installation_owner_key = content.owner_key
  from practice_generated_content content
 where conversation.status = 'active'
   and conversation.generated_content_id = content.generated_content_id
   and conversation.installation_ref_hash = content.installation_ref_hash
   and content.owner_scope = 'installation'
   and content.owner_key ~ '^owner_[0-9a-f]{64}$';

-- A generating/abnormal legacy row has no recoverable owner identity. It is a
-- short-lived reservation and is safer to recreate than to guess ownership.
delete from guest_onboarding_conversations
 where installation_owner_key is null;

alter table guest_onboarding_conversations
    alter column installation_owner_key set not null;

alter table guest_onboarding_conversations
    add constraint chk_guest_onboarding_conversations_owner_key
        check (installation_owner_key ~ '^owner_[0-9a-f]{64}$');

create table guest_onboarding_conversation_turns (
    turn_id varchar(37) not null,
    conversation_id varchar(37) not null,
    local_event_id varchar(96) not null,
    request_fingerprint varchar(68) not null,
    previous_utterance_id varchar(64) not null,
    parent_action varchar(16) not null,
    reaction_provided boolean not null,
    reaction varchar(24),
    generated_content_id varchar(64),
    utterance_id varchar(64),
    english_text varchar(240),
    chinese_text varchar(240),
    pronunciation_hint varchar(240),
    audio_ref varchar(256),
    status varchar(16) not null,
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    constraint pk_guest_onboarding_conversation_turns primary key (turn_id),
    constraint fk_guest_onboarding_turns_conversation foreign key (conversation_id)
        references guest_onboarding_conversations (conversation_id) on delete cascade,
    constraint uq_guest_onboarding_turns_conversation_event unique (conversation_id, local_event_id),
    constraint chk_guest_onboarding_turns_parent_action check (parent_action = 'said_it'),
    constraint chk_guest_onboarding_turns_reaction check (
        (not reaction_provided and reaction is null)
        or
        (reaction_provided and reaction in ('cooperating', 'hesitant', 'resisting', 'no_response', 'other'))
    ),
    constraint chk_guest_onboarding_turns_status check (status in ('generating', 'active')),
    constraint chk_guest_onboarding_turns_status_payload check (
        (status = 'generating'
            and generated_content_id is null
            and utterance_id is null
            and english_text is null
            and chinese_text is null
            and pronunciation_hint is null)
        or
        (status = 'active'
            and generated_content_id is not null
            and utterance_id is not null
            and english_text is not null
            and chinese_text is not null
            and pronunciation_hint is not null)
    ),
    constraint chk_guest_onboarding_turns_expiry check (expires_at > created_at)
);

create index idx_guest_onboarding_turns_expires_at
    on guest_onboarding_conversation_turns (expires_at);
