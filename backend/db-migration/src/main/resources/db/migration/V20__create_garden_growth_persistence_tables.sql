create table garden_fertilizer_state (
    user_id varchar(128) primary key,
    applied_count integer not null default 0 check (applied_count >= 0),
    last_claimed_at timestamp with time zone,
    last_applied_at timestamp with time zone,
    version bigint not null default 0,
    updated_at timestamp with time zone not null default now()
);

create table garden_fertilizer_claim_log (
    id bigserial primary key,
    user_id varchar(128) not null,
    event_key varchar(128) not null,
    request_id varchar(128) not null,
    claimed_at timestamp with time zone not null default now(),
    constraint uk_garden_fertilizer_claim_log_user_event_key unique (user_id, event_key),
    constraint uk_garden_fertilizer_claim_log_user_request_id unique (user_id, request_id)
);
