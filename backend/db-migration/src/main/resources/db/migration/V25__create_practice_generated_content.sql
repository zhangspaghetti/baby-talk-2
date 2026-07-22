alter table baby_profiles
    add constraint uq_baby_profiles_profile_account
    unique (profile_id, account_id);

create table practice_generated_content (
    generated_content_id varchar(64) primary key,
    owner_scope varchar(24) not null,
    owner_key varchar(96) not null,
    owner_key_version varchar(32) not null,
    account_id varchar(64) null references accounts(account_id),
    installation_ref_hash varchar(96) null,
    profile_id varchar(64) null,
    surface varchar(32) not null,
    mode varchar(32) not null,
    request_fingerprint varchar(96) not null,
    normalized_scene_text varchar(160) null,
    age_range varchar(16) not null,
    parent_goal varchar(48) not null,
    locale varchar(16) not null,
    space_slug varchar(96) null,
    activity_slug varchar(96) null,
    phrase_slug varchar(120) null,
    space_title_zh varchar(120) null,
    activity_title_zh varchar(120) null,
    scene_tag_en varchar(120) null,
    coach_tip_zh varchar(240) null,
    english_text varchar(120) null,
    chinese_text varchar(120) null,
    pronunciation_hint varchar(120) null,
    difficulty varchar(16) null,
    generation_source varchar(32) null,
    status varchar(24) not null,
    provider_trace_id varchar(128) null,
    retrieval_trace_id varchar(128) null,
    model_name varchar(96) null,
    prompt_version varchar(48) not null,
    strategy_version varchar(48) not null,
    policy_version varchar(48) not null,
    content_version integer not null default 1,
    generation_error_code varchar(64) null,
    generation_started_at timestamp with time zone null,
    generation_expires_at timestamp with time zone null,
    retention_expires_at timestamp with time zone null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,

    constraint fk_practice_generated_content_profile_owner
        foreign key (profile_id, account_id)
        references baby_profiles(profile_id, account_id),
    constraint chk_practice_generated_content_owner_scope
        check (owner_scope in ('installation', 'account', 'profile', 'global_candidate')),
    constraint chk_practice_generated_content_surface
        check (surface in ('onboarding', 'scene_search', 'care_turn_support', 'mentor_generation')),
    constraint chk_practice_generated_content_mode
        check (mode = 'custom_scene'),
    constraint chk_practice_generated_content_generation_source
        check (generation_source is null or generation_source in ('agentic_search', 'rag_generation', 'manual', 'fake')),
    constraint chk_practice_generated_content_status
        check (status in ('draft', 'active', 'rejected', 'expired', 'promoted')),
    constraint chk_practice_generated_content_terminal_input_cleared
        check (status = 'draft' or normalized_scene_text is null),
    constraint chk_practice_generated_content_draft_shape
        check (
            status <> 'draft'
            or (
                normalized_scene_text is not null
                and generation_started_at is not null
                and generation_expires_at is not null
            )
        ),
    constraint chk_practice_generated_content_installation_retention
        check (
            owner_scope <> 'installation'
            or status not in ('active', 'rejected', 'expired')
            or retention_expires_at is not null
        ),
    constraint chk_practice_generated_content_installation_not_promoted
        check (owner_scope <> 'installation' or status <> 'promoted'),
    constraint chk_practice_generated_content_success_error_clear
        check (status not in ('active', 'promoted') or generation_error_code is null),
    constraint chk_practice_generated_content_content_version_positive
        check (content_version > 0),
    constraint chk_practice_generated_content_owner_shape
        check (
            (
                owner_scope = 'installation'
                and installation_ref_hash is not null
                and account_id is null
                and profile_id is null
            )
            or (
                owner_scope = 'account'
                and account_id is not null
                and installation_ref_hash is null
                and profile_id is null
            )
            or (
                owner_scope = 'profile'
                and account_id is not null
                and profile_id is not null
                and installation_ref_hash is null
            )
            or (
                owner_scope = 'global_candidate'
                and account_id is null
                and installation_ref_hash is null
                and profile_id is null
            )
        ),
    constraint chk_practice_generated_content_response_shape
        check (
            status not in ('active', 'promoted')
            or (
                space_slug is not null
                and activity_slug is not null
                and phrase_slug is not null
                and space_title_zh is not null
                and activity_title_zh is not null
                and scene_tag_en is not null
                and coach_tip_zh is not null
                and english_text is not null
                and chinese_text is not null
                and difficulty is not null
                and generation_source is not null
            )
        )
);

comment on column practice_generated_content.owner_key is
    'Already-HMACed owner key. Do not store raw owner identifiers in this column.';

comment on column practice_generated_content.owner_key_version is
    'Future migration metadata only; current runtime supports one active key version and does not perform key rotation.';

comment on column practice_generated_content.retention_expires_at is
    'Deletion eligibility timestamp for retention cleanup; installation rows receive status-based defaults in the application.';

create unique index uq_practice_generated_content_live_fingerprint
    on practice_generated_content(
        owner_key,
        owner_key_version,
        surface,
        mode,
        request_fingerprint,
        prompt_version,
        strategy_version,
        policy_version
    )
    where status in ('draft', 'active', 'promoted');

create unique index uq_practice_generated_content_active_space_slug
    on practice_generated_content(space_slug)
    where status in ('active', 'promoted');

create unique index uq_practice_generated_content_active_activity_slug
    on practice_generated_content(activity_slug)
    where status in ('active', 'promoted');

create unique index uq_practice_generated_content_active_phrase_slug
    on practice_generated_content(phrase_slug)
    where status in ('active', 'promoted');

create index idx_practice_generated_content_owner_created
    on practice_generated_content(owner_key, surface, mode, created_at desc);

create index idx_practice_generated_content_status_updated
    on practice_generated_content(status, updated_at desc);

create index idx_practice_generated_content_installation_cleanup
    on practice_generated_content(retention_expires_at, generated_content_id)
    where owner_scope = 'installation'
      and status in ('active', 'expired', 'rejected');

create index idx_practice_generated_content_stale_draft_cleanup
    on practice_generated_content(generation_expires_at, generated_content_id)
    where status = 'draft';

create index idx_practice_generated_content_account_cleanup
    on practice_generated_content(account_id, created_at desc)
    where owner_scope in ('account', 'profile');
