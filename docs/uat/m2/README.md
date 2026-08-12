# M2 Android UAT records

Copy one completed record per required case from [m2-uat-record.template.json](m2-uat-record.template.json) into `records/`. Use [m2-uat-record.schema.json](m2-uat-record.schema.json) for shape validation. Copy the exact `candidate_id`, SHA-256, and byte count of the ignored frozen-candidate manifest into every `candidate_manifest` reference. The shape schema keeps that additive field optional so historical v1 records remain readable; the closure verifier requires it.

`canonical_scene` must be exactly one approved controlled label: `shoes`, `bath`, `water`, `teeth`, `tidying`, or `sleep`. Unknown labels fail closed.

`dart tool/verify_m2_12_release_matrix.dart --records <directory> --manifest <ignored-manifest-path>` accepts individual record objects or JSON arrays. It only reports closure-ready when all five required cases are final `PASS`, reference the exact supplied manifest bytes, match its frozen nine-field candidate tuple, use real providers, include human TalkBack observations, and have no open defects. The manifest stores provider mode as `real`; UAT records use the equivalent controlled value `REAL`.

`records/` starts empty intentionally. Do not copy test fixtures there. Never record prompts, payloads, utterance bodies, credentials, tokens, account/device identifiers, raw errors, or private evidence.
