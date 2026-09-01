-- V38: persist the source and profile context used by unified scene generation.

alter table practice_generated_content
    add column input_source varchar(16) null,
    add column preset_activity_id bigint null,
    add column preset_scene_version_id bigint null,
    add column profile_version integer null,
    add column household_context_version varchar(16) null;

-- Existing rows are the legacy custom-scene shape. Keep them readable while
-- making their source explicit for consumers that opt into the new contract.
update practice_generated_content
set input_source = 'custom'
where mode = 'custom_scene'
  and input_source is null;

alter table practice_generated_content
    drop constraint chk_practice_generated_content_mode,
    add constraint chk_practice_generated_content_mode
        check (mode in ('custom_scene', 'scene_generation')),
    add constraint chk_practice_generated_content_input_source
        check (input_source is null or input_source in ('custom', 'preset')),
    add constraint fk_practice_generated_content_preset_scene
        foreign key (preset_activity_id, preset_scene_version_id)
        references practice_preset_scene_versions(activity_id, version_id),
    add constraint chk_practice_generated_content_scene_generation_shape
        check (
            mode <> 'scene_generation'
            or (
                owner_scope = 'profile'
                and input_source is not null
                and profile_version is not null
                and profile_version >= 0
                and household_context_version is not null
                and (
                    (input_source = 'custom'
                        and preset_activity_id is null
                        and preset_scene_version_id is null)
                    or (input_source = 'preset'
                        and preset_activity_id is not null
                        and preset_scene_version_id is not null)
                )
            )
        );

-- Legacy custom rows remain subject to the old slug uniqueness contract;
-- generated preset rows may reuse stable catalog slugs across weekly contexts.
drop index uq_practice_generated_content_active_space_slug;
drop index uq_practice_generated_content_active_activity_slug;
drop index uq_practice_generated_content_active_phrase_slug;

create unique index uq_practice_generated_content_active_space_slug
    on practice_generated_content(space_slug)
    where status = 'active'
      and (input_source is null or input_source <> 'preset');

create unique index uq_practice_generated_content_active_activity_slug
    on practice_generated_content(activity_slug)
    where status = 'active'
      and (input_source is null or input_source <> 'preset');

create unique index uq_practice_generated_content_active_phrase_slug
    on practice_generated_content(phrase_slug)
    where status = 'active'
      and (input_source is null or input_source <> 'preset');
