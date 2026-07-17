# P1 PostgreSQL schema compatibility evidence

## Scope

- Production migration unchanged.
- Added isolated-schema Flyway upgrade coverage in `DbMigrationSmokeTest`.
- Upgrade boundary: V22.1 to V23 on real PostgreSQL 16.13 via Testcontainers.

## Contract evidence

- V22.1 accepts and stores `calm`, `engaged`, `imitated`, and `needs_break`.
- V23 preserves all four rows and remaps them to `cooperating`, `cooperating`, `cooperating`, and `resisting`.
- V23 PostgreSQL constraint rejects new writes of every legacy value.
- V23 accepts and reads back all current values: `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`.
- Dedicated schema `flyway_v22_1_reaction_upgrade` avoids collision with existing V13 upgrade coverage and public-schema smoke tests.

## Verification

Command, with temporary uncommitted environment override:

```powershell
$env:TESTCONTAINERS_RYUK_DISABLED='true'; .\mvnw.cmd -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Result:

```text
Tests run: 7, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

`git diff --check`: passed.

## Self-review

- Assertions prove both data migration and post-upgrade write contract at PostgreSQL constraint level.
- Reviewer finding resolved: migration assertions bind each legacy `local_event_id` to its exact V23 value, preventing swapped-mapping false positives.
- Failed legacy inserts use unique primary keys, preventing false positives from duplicate-key violations.
- No migration or production code changed.
