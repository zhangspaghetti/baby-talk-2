# Issue #39 frozen candidate after #60 and #61

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 remains the required no-code human Android, audio, and TalkBack sign-off on this exact candidate. This freeze creates no `HUMAN_ANDROID` record and claims no human-heard result.

## Immutable candidate

- Candidate ID: `m2-final-ff07c74cfd1a`.
- Mobile source: `ff07c74cfd1aa3e08f115cfc946ed1de670a1e95`.
- APK SHA-256: `ff6a224c90ba7fdf07c328dace2c9afbaa168677e67b03f014406038626cd469`.
- APK size: `198904195` bytes.
- Backend source: `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`.
- Backend artifact: `image_sha256:7ac4094dfb8c777a1d09fec7968ab468cf3df052b210ac4e4a9fbb5fa48e0e55`.
- Environment: `sanitized-qa-kind-rev9`.
- Provider mode/profile: `real` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:355b305943af839770e7e2ad71a53da5869d20d537b01d281367c9ac003eeec0`.
- Ignored manifest: `artifacts/m2-final-ff07c74cfd1a-20260812.json`.
- Manifest SHA-256: `d1f236b358ccfc51a14228745c5285729e290e5bfaedefd7048a694fc166da57`.

This tuple supersedes `m2-final-d8e79613eb1a`. Git ancestry independently proves the unchanged deployed backend source is an ancestor of the mobile source, and the mobile source equals verification `HEAD`. The local debug APK and the APK pulled from the attached physical device have the exact SHA-256 and byte count above. Installation used `install -r`; app data, the signed-in UAT session, and accessibility settings were preserved.

## Live QA deployment identity

Read-only checks confirmed `babytalk-qa-app` Helm revision `9` is `deployed`. All four application Deployments are `1/1`; their current Pods are Ready with zero restarts. The app-api image ID is the immutable backend artifact recorded above. Gateway actuator health is `UP`.

The non-Secret Practice AI ConfigMap selects the agentic path using `glm-5.2`; Generator, Repair, and Quality Judge retain the version-locked v7 profile. The configuration fingerprint is SHA-256 over the exact UTF-8 tuple:

`9d5b636ad0a36a3bd4482acc42b768076fb7fe3b|custom-scene-generation-v7|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

Formal audio public configuration remains DashScope model `qwen-audio-3.0-tts-flash`, voice `loongeva_v3.6`, profile `qa-formal-v1`, and voice version `generated-tts-v1`. No Secret resource or value was read. `helm status -o json` was not used.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran once, serially, for `1344.7` seconds. It returned exit code `0`, all 13 receipts `PASS`, and zero violations:

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

No `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted. Full CI includes the #60 real-store recovery regression and #61 public logout, official-session failure, clearance, idempotency, privacy, routing, and semantics coverage.

Focused verifier, privacy, M2-11, Spring AI 2 static-source, and diff checks passed after the aggregate. Initial dual-axis review then found one Spec P1: the release-matrix verifier checked candidate tuples only against one another, not against the frozen manifest.

Remediation `5f43dc16` adds a privacy-safe `candidate_manifest` reference (`candidate_id`, manifest SHA-256, and byte count) to the UAT record contract. The release-matrix verifier now requires `--manifest`, validates that manifest through the M2-13 scanner, binds every record to the exact manifest bytes and frozen nine-field tuple, and normalizes manifest `real` to record `REAL`. Focused tests prove missing, wrong, and tampered manifests plus a self-consistent non-frozen tuple all fail closed. M2-12 and M2-13 focused tests passed `48/48`; targeted analyze, privacy, M2-11, Spring AI 2 static-source, JSON parsing, and diff checks passed.

The formal M2-13 verifier then reran all 13 upstream gates once, serially, on the clean remediation commit. It returned exit code `0`, zero violations, and the success marker in `139.3` seconds. This revalidation changes no APK, backend runtime, candidate tuple, or manifest bytes.

## UAT boundary

The ignored manifest is the only allowed candidate input to final UAT, and every final record must reference its exact ID, SHA-256, and byte count. This freeze does not start #40 and does not execute a final logout confirmation. Device inspection only preserved the candidate installation and identity; it does not become a human Android, human-heard audio, or TalkBack PASS.

No raw scene, prompt, provider request or response, utterance body, audio bytes, account, phone, device serial, request identity, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
