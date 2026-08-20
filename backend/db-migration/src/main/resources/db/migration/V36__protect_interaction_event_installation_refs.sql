-- Installation IDs and event keys are device identifiers. Historical values
-- cannot be re-keyed safely inside Flyway because the application HMAC pepper
-- is not available to migration SQL. Dispose every pre-V36 value, including
-- values that merely imitate the protected prefixes, with unique,
-- non-reversible tombstones. PostgreSQL 17 exposes gen_random_uuid() without
-- requiring the application HMAC pepper or a reversible derivation.
update interaction_events
set event_key = 'legacy-disposed:' || gen_random_uuid()::text,
    installation_id = 'legacy-disposed:' || gen_random_uuid()::text;

alter table interaction_events
    add constraint chk_interaction_events_installation_ref check (
        installation_id ~ '^v1:[A-Za-z0-9_-]{43}$'
        or installation_id ~ '^legacy-disposed:[0-9a-f-]{36}$'
    );

alter table interaction_events
    add constraint chk_interaction_events_event_key_ref check (
        event_key ~ '^e1:[A-Za-z0-9_-]{43}$'
        or event_key ~ '^legacy-disposed:[0-9a-f-]{36}$'
    );

-- New writes use an account-scoped HMAC event reference. The stable business
-- identity remains (account_id, local_event_id), so a historical raw replay
-- still conflicts as a duplicate after its stored references are disposed.
alter table interaction_events
    drop constraint if exists interaction_events_pkey;

alter table interaction_events
    add constraint pk_interaction_events_account_event_key primary key (account_id, event_key);

alter table interaction_events
    add constraint uq_interaction_events_account_local_event_id unique (account_id, local_event_id);
