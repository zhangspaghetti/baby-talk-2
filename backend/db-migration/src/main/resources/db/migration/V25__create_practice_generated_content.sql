alter table baby_profiles
    add constraint uq_baby_profiles_profile_account
    unique (profile_id, account_id);

create table practice_generated_content (
    generated_content_id varchar(64) not null,
    owner_scope varchar(24) not null,
    owner_key varchar(96) not null,
    owner_key_version varchar(32) not null,
    account_id varchar(64) null,
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
    tpr_action_zh varchar(240) null,
    delivery_guidance_zh varchar(240) null,
    english_text varchar(120) null,
    chinese_text varchar(120) null,
    pronunciation_hint varchar(120) null,
    difficulty varchar(16) null,
    generation_source varchar(32) null,
    status varchar(24) not null,
    generation_profile_version varchar(64) not null,
    generation_profile_hash char(64) not null,
    rubric_version varchar(64) not null,
    rubric_content_hash char(64) not null,
    evidence_policy_version varchar(64) not null,
    evidence_policy_content_hash char(64) not null,
    provider_routing_policy_version varchar(64) not null,
    provider_routing_policy_hash char(64) not null,
    generation_attempt_limit smallint not null,
    content_refresh_epoch integer not null default 1,
    content_version integer not null default 1,
    generation_error_code varchar(64) null,
    generation_error_retryable boolean null,
    generation_started_at timestamp with time zone null,
    generation_expires_at timestamp with time zone null,
    retention_expires_at timestamp with time zone null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,

    constraint pk_practice_generated_content
        primary key (generated_content_id),
    constraint fk_practice_generated_content_account
        foreign key (account_id)
        references accounts(account_id),
    constraint fk_practice_generated_content_profile_owner
        foreign key (profile_id, account_id)
        references baby_profiles(profile_id, account_id),
    constraint chk_practice_generated_content_owner_scope
        check (owner_scope in ('installation', 'account', 'profile')),
    constraint chk_practice_generated_content_surface
        check (surface in ('onboarding', 'scene_search', 'care_turn_support', 'mentor_generation')),
    constraint chk_practice_generated_content_mode
        check (mode = 'custom_scene'),
    constraint chk_practice_generated_content_generation_source
        check (generation_source is null or generation_source in ('agentic_search', 'rag_generation', 'manual', 'fake')),
    constraint chk_practice_generated_content_status
        check (status in ('draft', 'generating', 'active', 'rejected', 'expired')),
    constraint chk_practice_generated_content_terminal_input_cleared
        check (status not in ('active', 'rejected', 'expired') or normalized_scene_text is null),
    constraint chk_practice_generated_content_draft_shape
        check (
            status <> 'draft'
            or (
                normalized_scene_text is not null
                and generation_started_at is null
                and generation_expires_at is not null
            )
        ),
    constraint chk_practice_generated_content_generating_shape
        check (
            status <> 'generating'
            or (
                normalized_scene_text is not null
                and generation_started_at is not null
            )
        ),
    constraint chk_practice_generated_content_installation_retention
        check (
            owner_scope <> 'installation'
            or status not in ('active', 'rejected', 'expired')
            or retention_expires_at is not null
        ),
    constraint chk_practice_generated_content_success_error_clear
        check (
            (
                status in ('draft', 'generating', 'active')
                and generation_error_code is null
                and generation_error_retryable is null
            )
            or (
                status in ('rejected', 'expired')
                and generation_error_code is not null
                and generation_error_retryable is not null
            )
        ),
    constraint chk_practice_generated_content_content_version_positive
        check (content_version > 0),
    constraint chk_practice_generated_content_refresh_epoch_positive
        check (content_refresh_epoch > 0),
    constraint chk_practice_generated_content_attempt_limit
        check (generation_attempt_limit between 1 and 5),
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
        ),
    constraint chk_practice_generated_content_response_shape
        check (
            status <> 'active'
            or (
                space_slug is not null
                and activity_slug is not null
                and phrase_slug is not null
                and space_title_zh is not null
                and activity_title_zh is not null
                and scene_tag_en is not null
                and tpr_action_zh is not null
                and delivery_guidance_zh is not null
                and english_text is not null
                and chinese_text is not null
                and pronunciation_hint is not null
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

create function fn_practice_generated_content_terminal_status()
returns trigger
language plpgsql
as $$
begin
    if old.status in ('active', 'rejected', 'expired')
        and new.status is distinct from old.status then
        raise exception 'terminal practice_generated_content status cannot change'
            using errcode = '23514',
                  constraint = 'chk_practice_generated_content_terminal_transition';
    end if;
    return new;
end;
$$;

create trigger trg_practice_generated_content_terminal_status
before update of status on practice_generated_content
for each row
execute function fn_practice_generated_content_terminal_status();

create table practice_generated_content_attempts (
    attempt_id uuid not null,
    generated_content_id varchar(64) not null,
    attempt_number smallint not null,
    attempt_type varchar(16) not null,
    status varchar(16) not null,
    outcome varchar(32) null,
    violation_codes text[] not null default '{}',
    started_at timestamp with time zone not null,
    completed_at timestamp with time zone null,

    constraint pk_practice_generated_content_attempts
        primary key (attempt_id),
    constraint fk_practice_generated_content_attempts_content
        foreign key (generated_content_id)
        references practice_generated_content(generated_content_id)
        on delete cascade,
    constraint uq_practice_generated_content_attempt_number
        unique (generated_content_id, attempt_number),
    constraint chk_practice_generated_content_attempt_number
        check (attempt_number between 1 and 5),
    constraint chk_practice_generated_content_attempt_type
        check (attempt_type in ('generator', 'repair')),
    constraint chk_practice_generated_content_attempt_status
        check (status in ('started', 'completed', 'interrupted')),
    constraint chk_practice_generated_content_attempt_status_shape
        check (
            (status = 'started' and completed_at is null)
            or (status in ('completed', 'interrupted') and completed_at is not null)
        )
);

create table practice_ai_operation_runs (
    operation_run_id uuid not null,
    operation_type varchar(32) not null,
    subject_type varchar(32) not null,
    subject_id varchar(64) not null,
    generated_content_id varchar(64) not null,
    attempt_number smallint not null,
    evidence_bundle_id uuid null,
    capability_name varchar(64) not null,
    prompt_version varchar(64) not null,
    prompt_content_hash char(64) not null,
    policy_version varchar(64) null,
    policy_content_hash char(64) null,
    status varchar(16) not null,
    outcome varchar(32) null,
    started_at timestamp with time zone not null,
    completed_at timestamp with time zone null,

    constraint pk_practice_ai_operation_runs
        primary key (operation_run_id),
    constraint fk_practice_operation_runs_generated_content
        foreign key (generated_content_id)
        references practice_generated_content(generated_content_id)
        on delete cascade,
    constraint fk_practice_operation_runs_attempt
        foreign key (generated_content_id, attempt_number)
        references practice_generated_content_attempts(generated_content_id, attempt_number)
        on delete cascade,
    constraint chk_practice_operation_runs_operation_type
        check (operation_type in ('generator', 'quality_judge', 'repair')),
    constraint chk_practice_operation_runs_subject_type
        check (subject_type = 'generated_content'),
    constraint chk_practice_operation_runs_subject_identity
        check (subject_id = generated_content_id),
    constraint chk_practice_operation_runs_attempt_number
        check (attempt_number between 1 and 5),
    constraint chk_practice_operation_runs_policy_shape
        check ((policy_version is null) = (policy_content_hash is null)),
    constraint chk_practice_operation_runs_status
        check (status in ('started', 'completed', 'interrupted')),
    constraint chk_practice_operation_runs_status_shape
        check (
            (status = 'started' and completed_at is null)
            or (status in ('completed', 'interrupted') and completed_at is not null)
        )
);

create table practice_ai_provider_calls (
    provider_call_id uuid not null,
    operation_run_id uuid not null,
    provider_name varchar(64) not null,
    provider_type varchar(32) not null,
    model_name varchar(96) not null,
    fallback_index smallint not null,
    attempt_trace_id uuid not null,
    provider_trace_id varchar(128) null,
    routing_policy_version varchar(64) not null,
    routing_policy_hash char(64) not null,
    outcome varchar(32) not null,
    latency_ms bigint null,
    started_at timestamp with time zone not null,
    completed_at timestamp with time zone null,

    constraint pk_practice_ai_provider_calls
        primary key (provider_call_id),
    constraint fk_practice_provider_calls_operation_run
        foreign key (operation_run_id)
        references practice_ai_operation_runs(operation_run_id)
        on delete cascade,
    constraint uq_practice_provider_calls_attempt_trace
        unique (attempt_trace_id),
    constraint uq_practice_provider_calls_operation_provider
        unique (operation_run_id, provider_name),
    constraint chk_practice_provider_calls_fallback_index
        check (fallback_index >= 0),
    constraint chk_practice_provider_calls_latency
        check (latency_ms is null or latency_ms >= 0)
);

create table practice_generated_content_evidence_bundles (
    evidence_bundle_id uuid not null,
    generated_content_id varchar(64) not null,
    attempt_number smallint not null,
    derived_from_bundle_id uuid null,
    retrieval_outcome varchar(16) not null,
    retrieval_trace_id uuid null,
    evidence_policy_version varchar(64) not null,
    evidence_policy_content_hash char(64) not null,
    sanitizer_version varchar(64) not null,
    bundle_hash char(64) not null,
    evidence_count integer not null,
    created_at timestamp with time zone not null,

    constraint pk_practice_generated_content_evidence_bundles
        primary key (evidence_bundle_id),
    constraint fk_practice_evidence_bundles_generated_content
        foreign key (generated_content_id)
        references practice_generated_content(generated_content_id)
        on delete cascade,
    constraint fk_practice_evidence_bundles_attempt
        foreign key (generated_content_id, attempt_number)
        references practice_generated_content_attempts(generated_content_id, attempt_number)
        on delete cascade,
    constraint fk_practice_evidence_bundles_derived_from
        foreign key (derived_from_bundle_id)
        references practice_generated_content_evidence_bundles(evidence_bundle_id),
    constraint uq_practice_evidence_bundles_attempt
        unique (generated_content_id, attempt_number),
    constraint uq_practice_evidence_bundles_identity
        unique (evidence_bundle_id, generated_content_id, attempt_number),
    constraint chk_practice_evidence_bundles_attempt_number
        check (attempt_number between 1 and 5),
    constraint chk_practice_evidence_bundles_retrieval_outcome
        check (retrieval_outcome in ('initial', 'reused', 'refreshed')),
    constraint chk_practice_evidence_bundles_evidence_count
        check (evidence_count >= 0)
);

create table practice_generated_content_evidence_items (
    evidence_bundle_id uuid not null,
    evidence_ordinal integer not null,
    replay_mode varchar(16) not null,
    evidence_id varchar(128) not null,
    source_type varchar(48) not null,
    source_version varchar(64) null,
    strategy_id varchar(96) null,
    claim_type varchar(48) not null,
    sanitizer_version varchar(64) not null,
    sanitized_summary_hash char(64) not null,
    sanitized_summary_snapshot varchar(320) null,
    confidence numeric(5,4) not null,
    created_at timestamp with time zone not null,

    constraint pk_practice_generated_content_evidence_items
        primary key (evidence_bundle_id, evidence_ordinal),
    constraint fk_practice_evidence_items_bundle
        foreign key (evidence_bundle_id)
        references practice_generated_content_evidence_bundles(evidence_bundle_id)
        on delete cascade,
    constraint chk_practice_evidence_items_ordinal
        check (evidence_ordinal > 0),
    constraint chk_practice_evidence_items_replay_mode
        check (replay_mode in ('reference', 'snapshot')),
    constraint chk_practice_evidence_items_replay_shape
        check (
            (
                replay_mode = 'reference'
                and source_version is not null
                and sanitized_summary_snapshot is null
            )
            or (
                replay_mode = 'snapshot'
                and sanitized_summary_snapshot is not null
                and char_length(sanitized_summary_snapshot) between 1 and 320
            )
        ),
    constraint chk_practice_evidence_items_confidence
        check (confidence between 0 and 1)
);

alter table practice_ai_operation_runs
    add constraint fk_practice_operation_runs_evidence_bundle
    foreign key (evidence_bundle_id, generated_content_id, attempt_number)
    references practice_generated_content_evidence_bundles(
        evidence_bundle_id,
        generated_content_id,
        attempt_number
    );

create table practice_generated_content_judge_results (
    judge_result_id uuid not null,
    provider_call_id uuid not null,
    suggested_verdict varchar(16) not null,
    effective_verdict varchar(16) not null,
    verdict_consistency varchar(16) not null,
    dimension_results jsonb not null,
    violation_codes text[] not null default '{}',
    repair_directives text[] not null default '{}',
    evidence_gap_codes text[] not null default '{}',
    judge_confidence numeric(5,4) null,
    rubric_version varchar(64) not null,
    rubric_content_hash char(64) not null,
    created_at timestamp with time zone not null,

    constraint pk_practice_generated_content_judge_results
        primary key (judge_result_id),
    constraint fk_practice_judge_results_provider_call
        foreign key (provider_call_id)
        references practice_ai_provider_calls(provider_call_id)
        on delete cascade,
    constraint uq_practice_judge_results_provider_call
        unique (provider_call_id),
    constraint chk_practice_judge_results_suggested_verdict
        check (suggested_verdict in ('pass', 'repair', 'reject', 'abstain')),
    constraint chk_practice_judge_results_effective_verdict
        check (effective_verdict in ('pass', 'repair', 'reject', 'abstain')),
    constraint chk_practice_judge_results_verdict_consistency
        check (verdict_consistency in ('consistent', 'inconsistent')),
    constraint chk_practice_judge_results_dimensions
        check (jsonb_typeof(dimension_results) = 'object'),
    constraint chk_practice_judge_results_confidence
        check (judge_confidence is null or judge_confidence between 0 and 1)
);

create unique index uq_practice_generated_content_live_fingerprint
    on practice_generated_content(
        owner_key,
        owner_key_version,
        surface,
        mode,
        request_fingerprint,
        generation_profile_version,
        content_refresh_epoch
    )
    where status in ('draft', 'generating', 'active');

create unique index uq_practice_generated_content_active_space_slug
    on practice_generated_content(space_slug)
    where status = 'active';

create unique index uq_practice_generated_content_active_activity_slug
    on practice_generated_content(activity_slug)
    where status = 'active';

create unique index uq_practice_generated_content_active_phrase_slug
    on practice_generated_content(phrase_slug)
    where status = 'active';

create index idx_practice_generated_content_owner_created
    on practice_generated_content(
        owner_key,
        owner_key_version,
        surface,
        mode,
        created_at desc
    );

create index idx_practice_generated_content_status_updated
    on practice_generated_content(status, updated_at desc);

create index idx_practice_generated_content_installation_cleanup
    on practice_generated_content(retention_expires_at, generated_content_id)
    where owner_scope = 'installation'
      and status in ('active', 'expired', 'rejected');

create index idx_practice_generated_content_stale_draft_cleanup
    on practice_generated_content(generation_expires_at, generated_content_id)
    where status in ('draft', 'generating');

create index idx_practice_generated_content_account_cleanup
    on practice_generated_content(account_id, created_at desc)
    where owner_scope in ('account', 'profile');

create index idx_practice_operation_runs_generated_attempt
    on practice_ai_operation_runs(generated_content_id, attempt_number, started_at);
