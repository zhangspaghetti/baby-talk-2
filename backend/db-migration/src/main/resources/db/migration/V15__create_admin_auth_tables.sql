create table if not exists admin_principals (
    principal_id varchar(64) primary key,
    username varchar(64) not null unique,
    password_hash varchar(120) not null,
    display_name varchar(120) not null,
    status varchar(24) not null,
    created_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    constraint chk_admin_principals_status check (status in ('active', 'disabled'))
);

create table if not exists admin_roles (
    role_code varchar(64) primary key,
    description varchar(240) not null,
    created_at timestamp with time zone not null
);

create table if not exists admin_principal_roles (
    principal_id varchar(64) not null,
    role_code varchar(64) not null,
    granted_at timestamp with time zone not null,
    primary key (principal_id, role_code),
    constraint fk_admin_principal_roles_principal foreign key (principal_id) references admin_principals(principal_id) on delete cascade,
    constraint fk_admin_principal_roles_role foreign key (role_code) references admin_roles(role_code) on delete cascade
);

create table if not exists admin_refresh_tokens (
    refresh_token_id varchar(64) primary key,
    principal_id varchar(64) not null,
    status varchar(24) not null,
    issued_at timestamp with time zone not null,
    expires_at timestamp with time zone not null,
    updated_at timestamp with time zone not null,
    rotated_at timestamp with time zone null,
    revoked_at timestamp with time zone null,
    replacement_token_id varchar(64) null,
    constraint fk_admin_refresh_tokens_principal foreign key (principal_id) references admin_principals(principal_id) on delete cascade,
    constraint fk_admin_refresh_tokens_replacement foreign key (replacement_token_id) references admin_refresh_tokens(refresh_token_id),
    constraint chk_admin_refresh_tokens_status check (status in ('active', 'rotated', 'revoked', 'expired'))
);

create index if not exists idx_admin_refresh_tokens_principal_status on admin_refresh_tokens(principal_id, status);
create index if not exists idx_admin_refresh_tokens_status_expires_at on admin_refresh_tokens(status, expires_at);
create index if not exists idx_admin_principal_roles_role on admin_principal_roles(role_code, principal_id);
