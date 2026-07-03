create table baby_profiles (
    profile_id varchar(64) primary key,
    account_id varchar(64) not null references accounts(account_id),
    baby_name varchar(80) null,
    age_range varchar(16) not null,
    parent_goal varchar(48) null,
    starter_scene_id varchar(96) null,
    starter_moment_id varchar(96) null,
    starter_activity_id varchar(96) null,
    starter_utterance_id varchar(120) null,
    starter_phrase_id varchar(120) null,
    starter_source varchar(32) null,
    onboarding_state varchar(24) not null,
    onboarding_completed_at timestamp with time zone null,
    version integer not null default 1,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,

    constraint uq_baby_profiles_account_id unique (account_id),
    constraint chk_baby_profiles_baby_name_len
        check (baby_name is null or char_length(baby_name) <= 40),
    constraint chk_baby_profiles_age_range
        check (age_range in (
            'm0_3',
            'm4_6',
            'm7_11',
            'm12_17',
            'm18_23',
            'm24_30',
            'm31_36'
        )),
    constraint chk_baby_profiles_parent_goal
        check (parent_goal is null or parent_goal in (
            'natural_opening',
            'confident_pronunciation',
            'calmer_care',
            'keep_talking'
        )),
    constraint chk_baby_profiles_state
        check (onboarding_state in ('draft', 'completed')),
    constraint chk_baby_profiles_version_positive
        check (version >= 1),
    constraint chk_baby_profiles_starter_source
        check (starter_source is null or starter_source in ('catalog', 'generated')),
    constraint chk_baby_profiles_completed_shape
        check (
            onboarding_state <> 'completed'
            or (
                parent_goal is not null
                and starter_scene_id is not null
                and starter_moment_id is not null
                and starter_activity_id is not null
                and starter_utterance_id is not null
                and starter_phrase_id is not null
                and starter_source is not null
                and onboarding_completed_at is not null
            )
        )
);

create index idx_baby_profiles_updated_at
    on baby_profiles(updated_at desc);

create index idx_baby_profiles_state_updated_at
    on baby_profiles(onboarding_state, updated_at desc);
