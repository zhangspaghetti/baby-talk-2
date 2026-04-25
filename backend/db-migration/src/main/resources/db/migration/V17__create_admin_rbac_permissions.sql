create table if not exists admin_permissions (
    permission_code varchar(64) primary key,
    description varchar(240) not null,
    created_at timestamp with time zone not null
);

create table if not exists admin_role_permissions (
    role_code varchar(64) not null,
    permission_code varchar(64) not null,
    granted_at timestamp with time zone not null,
    primary key (role_code, permission_code),
    constraint fk_admin_role_permissions_role foreign key (role_code) references admin_roles(role_code) on delete cascade,
    constraint fk_admin_role_permissions_permission foreign key (permission_code) references admin_permissions(permission_code) on delete cascade
);

create index if not exists idx_admin_role_permissions_permission on admin_role_permissions(permission_code, role_code);

insert into admin_permissions (permission_code, description, created_at)
values
    ('users:read', 'Read consumer users.', current_timestamp),
    ('users:write', 'Manage consumer users.', current_timestamp),
    ('admins:read', 'Read admin principals.', current_timestamp),
    ('admins:write', 'Manage admin principals.', current_timestamp),
    ('rbac:read', 'Read admin roles and permissions.', current_timestamp),
    ('rbac:write', 'Manage admin roles and permissions.', current_timestamp),
    ('rag:read', 'Read RAG resources.', current_timestamp),
    ('rag:write', 'Manage RAG resources.', current_timestamp),
    ('kg:read', 'Read knowledge graph data.', current_timestamp),
    ('kg:review', 'Review knowledge graph changes.', current_timestamp),
    ('mentor:audit', 'Audit mentor operations.', current_timestamp),
    ('distribution:read', 'Read distribution reports.', current_timestamp)
on conflict (permission_code) do update
set description = excluded.description;

insert into admin_roles (role_code, description, created_at)
values ('super_admin', 'Built-in super admin role', current_timestamp)
on conflict (role_code) do nothing;

insert into admin_role_permissions (role_code, permission_code, granted_at)
select 'super_admin', permission_code, current_timestamp
from admin_permissions
on conflict (role_code, permission_code) do nothing;
