create table guest_onboarding_conversations (
    conversation_id varchar(37) not null,
    installation_ref_hash varchar(80) not null,
    local_event_id varchar(96) not null,
    request_fingerprint varchar(68) not null,
    registry_revision varchar(64) not null,
    care_entry_id varchar(128) not null,
    generation_namespace varchar(64) not null,
    generation_key varchar(96) not null,
    generation_version integer not null,
    generation_facets_json jsonb not null default '{}'::jsonb,
    locale varchar(16) not null,
    time_band varchar(16) not null,
    generated_content_id varchar(64),
    utterance_id varchar(64),
    english_text varchar(240),
    chinese_text varchar(240),
    pronunciation_hint varchar(240),
    audio_ref varchar(256),
    status varchar(16) not null default 'active',
    source varchar(32) not null default 'remote_generated',
    expires_at timestamp with time zone not null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    constraint pk_guest_onboarding_conversations primary key (conversation_id),
    constraint uq_guest_onboarding_conversations_install_event
        unique (installation_ref_hash, local_event_id),
    constraint chk_guest_onboarding_conversations_status
        check (status in ('generating', 'active')),
    constraint chk_guest_onboarding_conversations_status_payload
        check (
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
    constraint chk_guest_onboarding_conversations_source
        check (source in ('remote_generated')),
    constraint chk_guest_onboarding_conversations_scene_version
        check (generation_version > 0),
    constraint chk_guest_onboarding_conversations_expiry
        check (expires_at > created_at)
);

create index idx_guest_onboarding_conversations_expires_at
    on guest_onboarding_conversations (expires_at);

create index idx_guest_onboarding_conversations_generated_content
    on guest_onboarding_conversations (generated_content_id)
    where generated_content_id is not null;
