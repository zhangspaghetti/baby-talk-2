# M2 Android UAT records

Copy one completed record per required case from [m2-uat-record.template.json](m2-uat-record.template.json) into `records/`. Use [m2-uat-record.schema.json](m2-uat-record.schema.json) for shape validation.

`dart tool/verify_m2_12_release_matrix.dart --records <directory>` accepts individual record objects or JSON arrays. It only reports closure-ready when all five required cases are final `PASS`, share an exact candidate tuple, use real providers, include human TalkBack observations, and have no open defects.

`records/` starts empty intentionally. Do not copy test fixtures there. Never record prompts, payloads, utterance bodies, credentials, tokens, account/device identifiers, raw errors, or private evidence.
