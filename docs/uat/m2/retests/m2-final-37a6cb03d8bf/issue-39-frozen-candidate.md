# Issue #39 frozen candidate after #63

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 remains the required no-code human Android, audio, and TalkBack sign-off on this exact candidate. This freeze creates no `HUMAN_ANDROID` record and claims no human-heard result.

## Immutable candidate

- Candidate ID: `m2-final-37a6cb03d8bf`.
- Mobile source: `37a6cb03d8bfffd625d0ee16e19c25a1bd069af1`.
- APK SHA-256: `8c112b313bce3b96f8d381431b0ed22be54715c0a1371a03cf122cf6342c1b2b`.
- APK size: `171586315` bytes.
- Backend source: `dd71582a1093256421d3ec369cd3bf4b6a2b03da`.
- Backend artifact: `image_sha256:c7d7554496dc34f3f7bd75315684076541d34baf1b3cc566fb5e1135270ce347`.
- Environment: `sanitized-qa-kind-rev12`.
- Provider mode/profile: `real` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:d35afa0c260c2703d29336daea38315b26f8fed54835188139ae7ade188f84fb`.
- Ignored manifest: `artifacts/m2-final-37a6cb03d8bf-20260813.json`.
- Manifest SHA-256: `543d3c3e31bec36ddc44a1eb7090f6030083306c41bee93e96f6bc32fa9f02fd`.
- Manifest size: `2686` bytes.

This tuple supersedes `m2-final-dd71582a1093`. Issue #63 changed only the M2-12 evidence contract and synthetic verifier fixtures. The deployed backend remains the verified ancestor and immutable QA revision 12 artifact. A fresh debug APK was built from the new mobile source and installed with `install -r`; local and installed hashes and byte counts match exactly. Its bytes are unchanged because no mobile product source changed.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran serially on the ignored manifest. It returned exit code `0`, all 13 receipts `PASS`, and zero violations:

- `complete_bundle`
- `activation_safety_repair`
- `legacy_quarantine`
- `recovery_coordinator`
- `handoff_confirmation`
- `backend_real_tts`
- `mobile_formal_audio`
- `garden_today_continuity`
- `privacy`
- `static_source`
- `release_evidence_schema`
- `clean_worktree`
- `full_ci`

No `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted.

## UAT boundary

The ignored manifest is the only allowed candidate input to final UAT. Every final record must reference its exact candidate ID, SHA-256, and byte count. Human observations made against the superseded candidate are not copied into this tuple; the affected interaction must be confirmed again before a new final record is written. This freeze does not start #40.

No raw scene, prompt, provider request or response, utterance body, audio bytes, account, phone, device serial, request identity, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
