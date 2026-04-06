create table if not exists app_sessions (
    session_id varchar(64) primary key,
    snapshot_json text not null,
    created_at timestamp not null,
    updated_at timestamp not null,
    last_seen_at timestamp not null
);

create index if not exists idx_app_sessions_last_seen_at
    on app_sessions (last_seen_at);