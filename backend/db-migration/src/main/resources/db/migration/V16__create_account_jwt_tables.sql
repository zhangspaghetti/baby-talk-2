create table if not exists account_refresh_tokens (
    refresh_token_id varchar(64) primary key,
    account_id varchar(64) not null,
    session_id varchar(64) not null,
    status varchar(24) not null,
    issued_at timestamp with time zone not null,
    expires_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    rotated_at timestamp with time zone null,
    revoked_at timestamp with time zone null,
    replacement_token_id varchar(64) null,
    constraint fk_account_refresh_tokens_account foreign key (account_id) references accounts(account_id) on delete cascade,
    constraint fk_account_refresh_tokens_session foreign key (session_id) references account_sessions(session_id) on delete cascade,
    constraint fk_account_refresh_tokens_replacement foreign key (replacement_token_id) references account_refresh_tokens(refresh_token_id) deferrable initially deferred,
    constraint chk_account_refresh_tokens_status check (status in ('active', 'rotated', 'revoked', 'expired'))
);

create unique index if not exists uq_account_refresh_tokens_active_session
    on account_refresh_tokens(session_id)
    where status = 'active';

create index if not exists idx_account_refresh_tokens_account_status
    on account_refresh_tokens(account_id, status);

create index if not exists idx_account_refresh_tokens_session_status
    on account_refresh_tokens(session_id, status);

create index if not exists idx_account_refresh_tokens_status_expires_at
    on account_refresh_tokens(status, expires_at);
