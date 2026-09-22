-- V37: Versioned, published preset-scene content and admin governance.

create table practice_preset_scene_versions (
    version_id          bigserial       not null,
    activity_id         bigint          not null,
    version             integer         null,
    state               varchar(16)     not null,
    title_zh            varchar(120)    not null,
    summary_zh          varchar(240)    not null,
    scene_tag_en        varchar(120)    not null,
    coach_tip_zh        varchar(240)    not null,
    sort_order          integer         not null,
    generation_brief    varchar(1200)   not null,
    enabled             boolean         not null,
    lock_version        integer         not null default 0,
    created_by_admin_id varchar(64)     null,
    published_by_admin_id varchar(64)   null,
    created_at          timestamp with time zone not null,
    updated_at          timestamp with time zone not null,
    published_at        timestamp with time zone null,
    constraint pk_practice_preset_scene_versions primary key (version_id),
    constraint fk_practice_preset_scene_versions_activity
        foreign key (activity_id) references practice_activities(id),
    constraint fk_practice_preset_scene_versions_created_by
        foreign key (created_by_admin_id) references admin_principals(principal_id),
    constraint fk_practice_preset_scene_versions_published_by
        foreign key (published_by_admin_id) references admin_principals(principal_id),
    constraint uq_practice_preset_scene_versions_activity_version
        unique (activity_id, version_id),
    constraint chk_practice_preset_scene_versions_state
        check (state in ('draft', 'published')),
    constraint chk_practice_preset_scene_versions_number
        check ((state = 'draft' and version is null and published_at is null)
            or (state = 'published' and version is not null and version > 0 and published_at is not null)),
    constraint chk_practice_preset_scene_versions_fields
        check (length(btrim(title_zh)) > 0
            and length(btrim(summary_zh)) > 0
            and length(btrim(scene_tag_en)) > 0
            and length(btrim(coach_tip_zh)) > 0
            and length(btrim(generation_brief)) > 0),
    constraint chk_practice_preset_scene_versions_sort_order
        check (sort_order >= 0),
    constraint chk_practice_preset_scene_versions_lock
        check (lock_version >= 0)
);

create unique index uq_practice_preset_scene_versions_published
    on practice_preset_scene_versions(activity_id, version)
    where state = 'published';

create unique index uq_practice_preset_scene_versions_one_draft
    on practice_preset_scene_versions(activity_id)
    where state = 'draft';

create index idx_practice_preset_scene_versions_activity_state
    on practice_preset_scene_versions(activity_id, state, updated_at desc);

create table practice_preset_scene_audit (
    audit_id           bigserial       not null,
    activity_id        bigint          not null,
    action             varchar(24)     not null,
    source_version_id  bigint          null,
    target_version_id  bigint          null,
    admin_principal_id varchar(64)     null,
    change_summary     jsonb           null,
    created_at         timestamp with time zone not null,
    constraint pk_practice_preset_scene_audit primary key (audit_id),
    constraint fk_practice_preset_scene_audit_activity
        foreign key (activity_id) references practice_activities(id),
    constraint fk_practice_preset_scene_audit_source_version
        foreign key (source_version_id) references practice_preset_scene_versions(version_id),
    constraint fk_practice_preset_scene_audit_target_version
        foreign key (target_version_id) references practice_preset_scene_versions(version_id),
    constraint fk_practice_preset_scene_audit_admin_principal
        foreign key (admin_principal_id) references admin_principals(principal_id),
    constraint chk_practice_preset_scene_audit_action
        check (action in ('create_draft', 'update_draft', 'publish', 'disable', 'rollback'))
);

create index idx_practice_preset_scene_audit_activity_created_at
    on practice_preset_scene_audit(activity_id, created_at desc);

alter table practice_activities
    add column current_published_version_id bigint null;

alter table practice_activities
    add constraint fk_practice_activities_current_published_version
    foreign key (id, current_published_version_id)
    references practice_preset_scene_versions(activity_id, version_id)
    deferrable initially deferred;

create or replace function prevent_practice_preset_scene_published_mutation()
returns trigger
language plpgsql
as $$
begin
    if old.state = 'published' then
        raise exception using
            errcode = 'check_violation',
            message = 'Published preset scene versions are immutable',
            constraint = 'chk_practice_preset_scene_versions_published_immutable';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

create trigger trg_practice_preset_scene_versions_published_immutable
before update or delete on practice_preset_scene_versions
for each row
execute function prevent_practice_preset_scene_published_mutation();

create or replace function enforce_practice_activities_current_published_version()
returns trigger
language plpgsql
as $$
begin
    if new.current_published_version_id is not null
       and not exists (
           select 1
           from practice_preset_scene_versions v
           where v.version_id = new.current_published_version_id
             and v.activity_id = new.id
             and v.state = 'published'
       ) then
        raise exception using
            errcode = 'check_violation',
            message = 'current_published_version_id must reference a published version for the same activity',
            constraint = 'chk_practice_activities_current_published_version';
    end if;
    return new;
end;
$$;

create constraint trigger trg_practice_activities_current_published_version
after insert or update on practice_activities
deferrable initially deferred
for each row
execute function enforce_practice_activities_current_published_version();

-- The bundled catalog already has four activities. Add the fifth stable identity
-- before creating its published version.
insert into practice_activities (
    slug,
    space_id,
    title_zh,
    scene_tag_en,
    coach_tip,
    sort_order,
    source
)
select
    'post_cry_soothing',
    s.id,
    '哭后安抚',
    'Post-cry soothing',
    '放慢语速、靠近一点，先用稳定声音回应宝宝。',
    3,
    'seed'
from practice_spaces s
where s.slug = 'daily_care'
  and not exists (
      select 1
      from practice_activities a
      where a.slug = 'post_cry_soothing'
  );

with scene_seed (
    slug,
    title_zh,
    summary_zh,
    scene_tag_en,
    coach_tip_zh,
    sort_order,
    generation_brief
) as (
    values
        (
            'bath_time',
            '洗澡时间',
            '从暖水、泼水到收尾，一次完成三句真实可说出口的 bath time 短语。',
            'Bath time',
            '用慢速、夸张表情和重复节奏，让宝宝先把英语和舒服、安全的体验绑定起来。',
            1,
            '围绕暖水、泼水和收尾，生成温和、短小、可重复的洗澡互动；先回应宝宝的安全感，再逐步加入英文。'
        ),
        (
            'diaper_change',
            '换尿布',
            '围绕擦拭、整理和收尾，给换尿布场景两句可以立刻开口的安抚短语。',
            'Diaper change',
            '先说动作，再做动作，让宝宝把英文和被照顾的安全感连在一起。',
            2,
            '围绕擦拭、整理和收尾，生成简短、可预测的换尿布互动；用稳定语气说明动作并持续安抚宝宝。'
        ),
        (
            'post_cry_soothing',
            '哭后安抚',
            '宝宝刚哭过时，用一句短句先让宝宝知道你就在身边。',
            'Post-cry soothing',
            '放慢语速、靠近一点，先用稳定声音回应宝宝。',
            3,
            '围绕宝宝刚哭过的时刻，生成先表达陪伴和安全感的短句；保持靠近、稳定、低刺激的回应节奏。'
        ),
        (
            'feeding_time',
            '吃饭时间',
            '从张嘴到鼓励吞咽，用两句短语把喂饭时刻变成可重复的英文 cue。',
            'Feeding time',
            '一边递勺子一边说短句，节奏要稳，让宝宝先记住声音和动作的对应关系。',
            1,
            '围绕张嘴、递勺和鼓励吞咽，生成节奏稳定、低压力的喂饭互动；让英文声音和动作清晰对应。'
        ),
        (
            'bedtime',
            '睡前时间',
            '围绕调暗灯光和进入睡眠，给 bedtime 场景补上两句柔和、低刺激的英文短语。',
            'Bedtime',
            '放慢语速、压低音量，把 bedtime 的英文做成固定的收尾仪式。',
            2,
            '围绕调暗灯光和准备入睡，生成柔和、低刺激、可重复的睡前互动；放慢语速并保持固定收尾仪式。'
        )
)
insert into practice_preset_scene_versions (
    activity_id,
    version,
    state,
    title_zh,
    summary_zh,
    scene_tag_en,
    coach_tip_zh,
    sort_order,
    generation_brief,
    enabled,
    created_at,
    updated_at,
    published_at
)
select
    a.id,
    1,
    'published',
    s.title_zh,
    s.summary_zh,
    s.scene_tag_en,
    s.coach_tip_zh,
    s.sort_order,
    s.generation_brief,
    true,
    current_timestamp,
    current_timestamp,
    current_timestamp
from scene_seed s
join practice_activities a on a.slug = s.slug
where not exists (
    select 1
    from practice_preset_scene_versions v
    where v.activity_id = a.id
      and v.version = 1
      and v.state = 'published'
);

update practice_activities a
set current_published_version_id = v.version_id
from practice_preset_scene_versions v
where v.activity_id = a.id
  and v.state = 'published'
  and v.version = 1;

insert into admin_permissions (permission_code, description, created_at)
values
    ('practice:read', 'Read preset practice scenes.', current_timestamp),
    ('practice:write', 'Create and edit preset practice scene drafts.', current_timestamp),
    ('practice:publish', 'Publish, disable, and roll back preset practice scenes.', current_timestamp)
on conflict (permission_code) do update
set description = excluded.description;

insert into admin_role_permissions (role_code, permission_code, granted_at)
select 'super_admin', permission_code, current_timestamp
from admin_permissions
where permission_code in ('practice:read', 'practice:write', 'practice:publish')
on conflict (role_code, permission_code) do nothing;
