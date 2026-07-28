-- M2 keeps legacy onboarding rows readable while making care_path activation a closed bundle.
alter table practice_generated_content
    drop constraint chk_practice_generated_content_surface,
    add constraint chk_practice_generated_content_surface
        check (surface in ('onboarding', 'care_path', 'scene_search', 'care_turn_support', 'mentor_generation'));

create table practice_generated_content_utterances (
    utterance_id varchar(64) not null,
    generated_content_id varchar(64) not null,
    role varchar(24) not null,
    reaction_type varchar(24) null,
    english_text varchar(120) not null,
    chinese_text varchar(120) not null,
    pronunciation_hint varchar(120) not null,
    tpr_action_zh varchar(240) not null,
    delivery_guidance_zh varchar(240) not null,
    difficulty varchar(16) not null,
    display_order smallint not null,
    approval_status varchar(16) not null,
    approved_content_version integer not null,
    created_at timestamp with time zone not null,

    constraint pk_practice_generated_content_utterances primary key (utterance_id),
    constraint fk_practice_generated_content_utterances_content
        foreign key (generated_content_id)
        references practice_generated_content(generated_content_id)
        on delete cascade,
    constraint chk_practice_generated_content_utterances_role
        check (role in ('starter', 'reaction_support')),
    constraint chk_practice_generated_content_utterances_reaction
        check (
            (role = 'starter' and reaction_type is null and display_order = 1)
            or (
                role = 'reaction_support'
                and reaction_type in ('cooperating', 'hesitant', 'resisting', 'no_response', 'other')
                and display_order between 2 and 6
            )
        ),
    constraint chk_practice_generated_content_utterances_approval
        check (approval_status = 'approved'),
    constraint chk_practice_generated_content_utterances_content_version
        check (approved_content_version > 0)
);

create unique index uq_practice_generated_content_utterances_starter
    on practice_generated_content_utterances(generated_content_id)
    where role = 'starter';

create unique index uq_practice_generated_content_utterances_reaction
    on practice_generated_content_utterances(generated_content_id, reaction_type)
    where role = 'reaction_support';

create unique index uq_practice_generated_content_utterances_display_order
    on practice_generated_content_utterances(generated_content_id, display_order);

create index idx_practice_generated_content_utterances_content_order
    on practice_generated_content_utterances(generated_content_id, display_order);

create function fn_practice_generated_content_care_path_bundle_shape()
returns trigger
language plpgsql
as $$
declare
    bundle_content_id varchar(64);
    bundle_content_version integer;
    bundle_is_active boolean;
    bundle_is_valid boolean;
begin
    bundle_content_id := case
        when tg_op = 'DELETE' then old.generated_content_id
        else new.generated_content_id
    end;

    select status = 'active' and surface = 'care_path', content_version
    into bundle_is_active, bundle_content_version
    from practice_generated_content
    where generated_content_id = bundle_content_id;

    if coalesce(bundle_is_active, false) then
        select
            count(*) = 6
            and count(*) filter (where role = 'starter') = 1
            and count(*) filter (where role = 'reaction_support') = 5
            and count(distinct reaction_type) filter (where role = 'reaction_support') = 5
            and count(*) filter (where approved_content_version = bundle_content_version) = 6
        into bundle_is_valid
        from practice_generated_content_utterances
        where generated_content_id = bundle_content_id;

        if not coalesce(bundle_is_valid, false) then
            raise exception 'active care_path generated content requires one starter and five reaction supports'
                using errcode = '23514',
                      constraint = 'chk_practice_generated_content_care_path_bundle_shape';
        end if;
    end if;

    return null;
end;
$$;

create constraint trigger trg_practice_generated_content_care_path_bundle_parent
after insert or update of status, surface, content_version or delete
on practice_generated_content
deferrable initially deferred
for each row
execute function fn_practice_generated_content_care_path_bundle_shape();

create constraint trigger trg_practice_generated_content_care_path_bundle_utterance
after insert or update or delete
on practice_generated_content_utterances
deferrable initially deferred
for each row
execute function fn_practice_generated_content_care_path_bundle_shape();
