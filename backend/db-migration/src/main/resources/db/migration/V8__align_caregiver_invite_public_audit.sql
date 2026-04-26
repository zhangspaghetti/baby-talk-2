alter table caregiver_invite_events
    drop constraint if exists chk_caregiver_invite_events_result;

alter table caregiver_invite_events
    add constraint chk_caregiver_invite_events_result check (
        result in (
            'create',
            'page_view',
            'open_app_redirect',
            'download_fallback',
            'accept',
            'invalid',
            'expired',
            'already_used',
            'revoked',
            'role_not_allowed',
            'shared_context_unavailable',
            'unavailable'
        )
    );

create index if not exists idx_caregiver_invite_events_source_platform_result
    on caregiver_invite_events(source, platform, result, created_at);
