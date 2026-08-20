-- Installation IDs and event keys are device identifiers. Historical raw
-- values cannot be re-keyed safely inside Flyway because the application HMAC
-- pepper is not available to migration SQL. Dispose each value with a unique,
-- non-reversible tombstone. PostgreSQL 17 exposes gen_random_uuid() without
-- requiring the application HMAC pepper or a reversible derivation.
update interaction_events
set event_key = case
                    when event_key ~ '^e1:[A-Za-z0-9_-]{43}$' then event_key
                    else 'legacy-disposed:' || gen_random_uuid()::text
                end,
    installation_id = case
                          when installation_id ~ '^v1:[A-Za-z0-9_-]{43}$' then installation_id
                          else 'legacy-disposed:' || gen_random_uuid()::text
                      end
where event_key !~ '^e1:[A-Za-z0-9_-]{43}$'
   or installation_id !~ '^v1:[A-Za-z0-9_-]{43}$';

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

-- New writes use an account-scoped HMAC event reference. Historical raw
-- replays are intentionally no longer idempotent after their raw key has been
-- disposed; the service still accepts them as new events under the new key.
alter table interaction_events
    drop constraint if exists interaction_events_pkey;

alter table interaction_events
    add constraint pk_interaction_events_account_event_key primary key (account_id, event_key);
