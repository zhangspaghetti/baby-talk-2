alter table garden_fertilizer_state
    add constraint ck_garden_fertilizer_state_applied_count_non_negative
        check (applied_count >= 0);

create table if not exists garden_fertilizer_apply_log (
    id bigserial primary key,
    user_id varchar(128) not null,
    request_id varchar(128) not null,
    delta integer not null,
    applied_at timestamp with time zone not null default now(),
    unique (user_id, request_id)
);
