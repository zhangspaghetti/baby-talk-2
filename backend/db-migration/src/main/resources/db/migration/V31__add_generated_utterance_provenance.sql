-- Complete generated bundles retain per-utterance provenance. Legacy rows remain readable only
-- as legacy storage; application queries reject them until a future quarantine/purge policy runs.
alter table practice_generated_content_utterances
    add column bundle_schema_version varchar(64) null,
    add column provider_origin varchar(32) null,
    add column provider_name varchar(120) null,
    add column provider_model_name varchar(120) null,
    add column provider_attempt_number smallint null,
    add constraint chk_practice_generated_content_utterances_provenance
        check (
            (
                bundle_schema_version is null
                and provider_origin is null
                and provider_name is null
                and provider_model_name is null
                and provider_attempt_number is null
            )
            or (
                bundle_schema_version = 'custom-scene-generated-output-v1'
                and provider_origin in ('provider_generated', 'provider_repaired')
                and nullif(btrim(provider_name), '') is not null
                and nullif(btrim(provider_model_name), '') is not null
                and provider_attempt_number between 1 and 5
            )
        );

-- V29/V30 active rows without a complete V31 bundle are quarantined, never repaired in place.
create or replace function fn_practice_generated_content_terminal_status()
returns trigger
language plpgsql
as $$
begin
    if old.status = 'active'
        and new.status = 'expired'
        and new.generation_error_code = 'legacy_active_bundle_unsupported'
        and new.generation_error_retryable is true then
        return new;
    end if;
    if old.status in ('active', 'rejected', 'expired')
        and new.status is distinct from old.status then
        raise exception 'terminal practice_generated_content status cannot change'
            using errcode = '23514',
                  constraint = 'chk_practice_generated_content_terminal_transition';
    end if;
    return new;
end;
$$;

create or replace function fn_practice_generated_content_care_path_bundle_shape()
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
            and count(*) filter (
                where role = 'starter'
                  and reaction_type is null
                  and display_order = 1
            ) = 1
            and count(*) filter (
                where role = 'reaction_support'
                  and reaction_type = 'cooperating'
                  and display_order = 2
            ) = 1
            and count(*) filter (
                where role = 'reaction_support'
                  and reaction_type = 'hesitant'
                  and display_order = 3
            ) = 1
            and count(*) filter (
                where role = 'reaction_support'
                  and reaction_type = 'resisting'
                  and display_order = 4
            ) = 1
            and count(*) filter (
                where role = 'reaction_support'
                  and reaction_type = 'no_response'
                  and display_order = 5
            ) = 1
            and count(*) filter (
                where role = 'reaction_support'
                  and reaction_type = 'other'
                  and display_order = 6
            ) = 1
            and count(*) filter (where approved_content_version = bundle_content_version) = 6
            and count(*) filter (
                where bundle_schema_version = 'custom-scene-generated-output-v1'
                  and provider_origin in ('provider_generated', 'provider_repaired')
                  and nullif(btrim(provider_name), '') is not null
                  and nullif(btrim(provider_model_name), '') is not null
                  and provider_attempt_number between 1 and 5
            ) = 6
        into bundle_is_valid
        from practice_generated_content_utterances
        where generated_content_id = bundle_content_id;

        if not coalesce(bundle_is_valid, false) then
            raise exception 'active care_path generated content requires a complete provenance-bearing bundle'
                using errcode = '23514',
                      constraint = 'chk_practice_generated_content_care_path_bundle_shape';
        end if;
    end if;

    return null;
end;
$$;
