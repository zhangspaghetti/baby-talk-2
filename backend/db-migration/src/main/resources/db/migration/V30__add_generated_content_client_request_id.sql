alter table practice_generated_content
    add column client_request_id varchar(96) null,
    add column client_request_fingerprint varchar(96) null,
    add constraint chk_practice_generated_content_client_request_id
        check (
            client_request_id is null
            or (
                client_request_id ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,95}$'
                and client_request_id !~ '[0-9]{11,}'
            )
        ),
    add constraint chk_practice_generated_content_client_request_fingerprint
        check (
            (client_request_id is null and client_request_fingerprint is null)
            or (
                client_request_id is not null
                and client_request_fingerprint ~ '^crf_[0-9a-f]{64}$'
            )
        );

create unique index uq_practice_generated_content_owner_client_request
    on practice_generated_content(owner_scope, owner_key, owner_key_version, client_request_id)
    where client_request_id is not null;
