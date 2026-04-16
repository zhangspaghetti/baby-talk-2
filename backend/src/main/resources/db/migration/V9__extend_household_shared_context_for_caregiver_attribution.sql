alter table household_shared_context
    add column if not exists latest_actor_role varchar(32) null;

alter table household_shared_context
    add column if not exists latest_actor_source varchar(32) null;

alter table household_shared_context
    add column if not exists latest_actor_result varchar(32) null;

alter table household_shared_context
    add column if not exists next_step_space_id varchar(64) null;

alter table household_shared_context
    add column if not exists next_step_activity_id varchar(64) null;

alter table household_shared_context
    add column if not exists next_step_reason varchar(32) null;
