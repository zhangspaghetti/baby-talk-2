-- Existing historical raw values are disposed during this one-way migration.
-- New lookup values are keyed HMAC references made by the application.
alter table accounts add column phone_lookup_ref varchar(96);
alter table accounts add column phone_mask varchar(24);
alter table sms_challenges add column phone_lookup_ref varchar(96);
alter table sms_challenges add column phone_mask varchar(24);
alter table sms_challenges add column verification_verifier varchar(192);
alter table sms_challenges add column verification_attempts integer not null default 0;

-- Legacy rows cannot be safely re-keyed without an application-held secret.
-- Replace raw values with non-reversible disposal references; accounts must re-verify once.
update accounts
set phone_lookup_ref = 'legacy-disposed:' || account_id,
    phone_mask = '已保护号码';

update sms_challenges
set phone_lookup_ref = 'legacy-disposed:' || challenge_id,
    phone_mask = '已保护号码',
    verification_verifier = 'legacy-disposed';

alter table accounts alter column phone_lookup_ref set not null;
alter table accounts alter column phone_mask set not null;
alter table sms_challenges alter column phone_lookup_ref set not null;
alter table sms_challenges alter column phone_mask set not null;
alter table sms_challenges alter column verification_verifier set not null;

alter table accounts drop constraint if exists accounts_phone_number_key;
alter table accounts drop column phone_number;
alter table sms_challenges drop column verification_code;
alter table sms_challenges drop column phone_number;

alter table accounts add constraint uq_accounts_phone_lookup_ref unique (phone_lookup_ref);
alter table sms_challenges add constraint chk_sms_challenges_verification_attempts
    check (verification_attempts between 0 and 5);
create index if not exists idx_sms_challenges_lookup_status
    on sms_challenges(phone_lookup_ref, status);
drop index if exists idx_sms_challenges_phone_status;
