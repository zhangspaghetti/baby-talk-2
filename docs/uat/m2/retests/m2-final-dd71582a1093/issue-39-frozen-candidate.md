# Issue #39 frozen candidate after #62

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 remains the required no-code human Android, audio, and TalkBack sign-off on this exact candidate. This freeze creates no `HUMAN_ANDROID` record and claims no human-heard result.

## Immutable candidate

- Candidate ID: `m2-final-dd71582a1093`.
- Mobile source: `dd71582a1093256421d3ec369cd3bf4b6a2b03da`.
- APK SHA-256: `8c112b313bce3b96f8d381431b0ed22be54715c0a1371a03cf122cf6342c1b2b`.
- APK size: `171586315` bytes.
- Backend source: `dd71582a1093256421d3ec369cd3bf4b6a2b03da`.
- Backend artifact: `image_sha256:c7d7554496dc34f3f7bd75315684076541d34baf1b3cc566fb5e1135270ce347`.
- Environment: `sanitized-qa-kind-rev12`.
- Provider mode/profile: `real` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:d35afa0c260c2703d29336daea38315b26f8fed54835188139ae7ade188f84fb`.
- Ignored manifest: `artifacts/m2-final-dd71582a1093-20260812.json`.
- Manifest SHA-256: `468e301197174ee669590bfeb792d58a98f392861baa90be69719f05dd5779ea`.
- Manifest size: `2686` bytes.

This tuple supersedes `m2-final-ff07c74cfd1a`. Issue #62 changed backend source, deployed app-api artifact, and the version-locked Repair prompt from v3 to v4. Mobile source advances to the same verification `HEAD`; local and installed debug APK hashes and byte counts match exactly after `install -r`, with app data preserved.

## Live QA deployment identity

Read-only checks confirmed `babytalk-qa-app` Helm revision `12` is `deployed`. All four application Deployments are `1/1`; current Pods are Ready with zero restarts. The app-api image uses immutable tag `m2-dd71582a`, and its image ID is the backend artifact recorded above. Gateway actuator health returned HTTP 200.

The non-Secret Practice AI ConfigMap selects the real agentic path and model `glm-5.2`. Generator, Repair, and Quality Judge use the version-locked v7 profile; Repair is now v4. The configuration fingerprint is SHA-256 over the exact UTF-8 tuple:

`dd71582a1093256421d3ec369cd3bf4b6a2b03da|custom-scene-generation-v7|custom-scene-generator-v3|custom-scene-repair-v4|custom-scene-quality-judge-v3`

No Secret resource or value was read. `helm status -o json` was not used.

## Operational acceptance before freeze

One privacy-safe synthetic sleep-class request was submitted on QA after #62 deployment. The same request used the official result reconciliation path and reached an interactive six-branch Today starter with sleep semantics and no bath semantics. No second request was created. This proves runtime repair convergence only; it is not a final human UAT record and makes no sensory, audio, or TalkBack claim.

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

The ignored manifest is the only allowed candidate input to final UAT. Every final record must reference its exact candidate ID, SHA-256, and byte count. This freeze does not start #40.

No raw scene, prompt, provider request or response, utterance body, audio bytes, account, phone, device serial, request identity, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
