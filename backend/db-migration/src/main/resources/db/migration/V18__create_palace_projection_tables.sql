create table if not exists palace_rooms (
    id uuid default uuid_generate_v4() primary key,
    wing varchar(120) not null,
    room varchar(120) not null,
    hall varchar(120) null,
    last_updated timestamp with time zone not null default now(),
    source_book_count int not null default 0
);

create index if not exists idx_palace_rooms_wing_room on palace_rooms (wing, room);

create table if not exists palace_bridge_edges (
    id uuid default uuid_generate_v4() primary key,
    room_a_id uuid not null,
    room_b_id uuid not null,
    confidence numeric(5, 4) not null default 0,
    status varchar(20) not null default 'proposed' check (status in ('proposed', 'approved', 'rejected')),
    source_book_a text not null,
    source_book_b text not null,
    created_at timestamp with time zone not null default now(),
    reviewed_by text null,
    reviewed_at timestamp with time zone null,
    constraint fk_palace_bridge_edges_room_a
        foreign key (room_a_id) references palace_rooms(id) on delete cascade,
    constraint fk_palace_bridge_edges_room_b
        foreign key (room_b_id) references palace_rooms(id) on delete cascade,
    constraint chk_palace_bridge_edges_distinct_rooms
        check (room_a_id <> room_b_id)
);

create index if not exists idx_palace_bridge_edges_status on palace_bridge_edges (status);
create index if not exists idx_palace_bridge_edges_room_a_id on palace_bridge_edges (room_a_id);
create index if not exists idx_palace_bridge_edges_room_b_id on palace_bridge_edges (room_b_id);

create table if not exists palace_projection_version (
    id uuid default uuid_generate_v4() primary key,
    version_num bigint not null,
    last_ingestion_batch_id uuid null,
    created_at timestamp with time zone not null default now(),
    status varchar(20) not null default 'current' check (status in ('current', 'rebuilding', 'stale')),
    room_count int not null default 0,
    constraint fk_palace_projection_version_ingestion_job
        foreign key (last_ingestion_batch_id) references ingestion_jobs(id) on delete set null
);

create table if not exists palace_query_traces (
    id uuid default uuid_generate_v4() primary key,
    entry_rooms jsonb not null default '[]'::jsonb,
    temporal_rule_applied varchar(240) not null,
    candidates_json jsonb not null default '[]'::jsonb,
    bridge_edges_crossed jsonb not null default '[]'::jsonb,
    projection_version_used bigint null,
    queried_at timestamp with time zone not null default now(),
    installation_id text null
);

create index if not exists idx_palace_query_traces_queried_at_desc on palace_query_traces (queried_at desc);
create index if not exists idx_palace_query_traces_installation_id on palace_query_traces (installation_id);
