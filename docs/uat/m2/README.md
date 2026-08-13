# M2 Android UAT records

Copy one completed record per required case from [m2-uat-record.template.json](m2-uat-record.template.json) into `records/`. Use [m2-uat-record.schema.json](m2-uat-record.schema.json) for shape validation. Copy the exact `candidate_id`, SHA-256, and byte count of the ignored frozen-candidate manifest into every `candidate_manifest` reference. The shape schema keeps that additive field optional so historical v1 records remain readable; the closure verifier requires it.

Current closure records use schema `m2_android_uat_v2`. `input_mode` must be exactly `custom_scene`; `scenario_label` separately records one privacy-safe controlled classification: `shoes`, `bath`, `water`, `teeth`, `tidying`, or `sleep`. Unknown modes or labels fail closed. Historical v1 records remain readable as archived evidence but cannot satisfy current closure.

For the generated-flow record, use the controlled prerequisite `approved_custom_scene_scenario` and action `submit_custom_scene`; never describe this route as canonical-scene submission.

`dart tool/verify_m2_12_release_matrix.dart --records <directory> --manifest <ignored-manifest-path>` accepts individual record objects or JSON arrays. It only reports closure-ready when all five required cases are final `PASS`, reference the exact supplied manifest bytes, match its frozen nine-field candidate tuple, use real providers, include human TalkBack observations, and have no open defects. The manifest stores provider mode as `real`; UAT records use the equivalent controlled value `REAL`.

`records/` starts empty intentionally. Do not copy test fixtures there. Never record prompts, payloads, utterance bodies, credentials, tokens, account/device identifiers, raw errors, or private evidence.

For emulator-based completion of pending audio checks, use [Android 模拟器音频 UAT 安装](../../runbooks/android-emulator-audio-uat.md). Emulator playback still requires human listening; successful installation or machine audio inspection alone cannot satisfy the UAT record.
