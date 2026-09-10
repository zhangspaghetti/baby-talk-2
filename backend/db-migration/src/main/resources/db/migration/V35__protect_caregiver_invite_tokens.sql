-- Invite tokens are bearer secrets.  Historical raw values cannot be safely
-- re-keyed without the application-held sensitive-data pepper, so dispose of
-- them and invalidate any pending invite before the new HMAC lookup contract.
update caregiver_invites
set status = case when status = 'pending' then 'revoked' else status end,
    revoked_at = case when status = 'pending' then coalesce(revoked_at, current_timestamp) else revoked_at end,
    failure_reason = case when status = 'pending' then 'legacy_token_disposed' else failure_reason end,
    token = 'legacy-disposed:' || invite_id;

update caregiver_invite_events
set token = case when token is null then null else 'legacy-disposed:' || event_id end;

alter table caregiver_invites
    add constraint chk_caregiver_invites_token_lookup_ref check (
        token ~ '^v1:[A-Za-z0-9_-]{43}$' or token ~ '^legacy-disposed:[A-Za-z0-9_-]+$'
    );

alter table caregiver_invite_events
    add constraint chk_caregiver_invite_events_token_lookup_ref check (
        token is null or token ~ '^v1:[A-Za-z0-9_-]{43}$' or token ~ '^legacy-disposed:[A-Za-z0-9_-]+$'
    );

-- New rows must use v1:<HMAC-SHA-256(base64url)> lookup references.  The
-- application writes this value into the existing unique token column; raw
-- bearer tokens remain only in the one-time create response/client URL.
