# Issue #39 frozen final candidate after #56 prepared-content reopen fix

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 still requires final no-code human Android/TalkBack sign-off on this exact candidate. Issue #53 still requires final human confirmation that starter and all five reaction branches are audible and match the displayed text. Issue #56 still requires its frozen-candidate device reopen check. No `HUMAN_ANDROID`, human-heard audio, or device reopen PASS is claimed here.

## Immutable candidate

- Candidate ID: `m2-final-5078e58dde5f`.
- Mobile source: `5078e58dde5f827da03241702f3122a558159d8a`.
- APK SHA-256: `8f785581b14afff57f3185b1dec8cf2943e1654c785ff8bdd663ce1bd5421276`.
- APK size: `171586151` bytes.
- Backend source: `0f79f451bd821ba94815885d130585757d7b8005`.
- Backend artifact: `image_sha256:8e19c186c92e3683fd64a77cdbeb89871afd9223cf948760cc14e1a6b29093ec`.
- Environment: `sanitized-qa-kind-rev5`.
- Release generation provider mode/profile: `real` / `qa-dashscope-qwen`.
- Generation model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:072195c3c7b4ba0fe98278c94cc5cfd2c67e435294783ac4ade72ad951c28435`.
- Frozen manifest: `artifacts/m2-final-5078e58dde5f-20260810.json`.
- Manifest SHA-256: `3dc00e4c9bf1e42e3614d7aad9592f0d71361bc3cd8d4c7673c26c1fd15affb7`.

This tuple supersedes `m2-final-c7091fedd536`. Mobile source and APK changed through the #56 prepared-content reopen fix. Backend source, deployed backend artifact, environment, provider profile, model identity, and public configuration fingerprint are unchanged.

## Live QA deployment identity

Read-only checks before the Gate run confirmed `babytalk-qa-app` Helm revision `5` remains `deployed`. All four application Deployments are ready. The live app-api Pod is ready with zero restarts, uses immutable tag `babytalk/app-api:m2-0f79f451`, and reports image ID `sha256:8e19c186c92e3683fd64a77cdbeb89871afd9223cf948760cc14e1a6b29093ec`. Repository history resolves the backend source to `0f79f451bd821ba94815885d130585757d7b8005`, which is an ancestor of the mobile candidate.

Local and installed test-emulator base APK identities both equal the frozen APK SHA-256 and byte size.

The live non-secret practice-AI ConfigMap selects the agentic path through `dashscope-qwen` with model `glm-5.2`. SHA-256 of the exact UTF-8 model name is:

`bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`

No runtime override replaces the backend's version-locked default profile. At backend source `0f79f451bd821ba94815885d130585757d7b8005`, the sanitized source/profile/prompt-version tuple is:

`0f79f451bd821ba94815885d130585757d7b8005|custom-scene-generation-v6|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

SHA-256 over that exact UTF-8 string, with no surrounding whitespace or final newline, is `072195c3c7b4ba0fe98278c94cc5cfd2c67e435294783ac4ade72ad951c28435`.

The same live app-api deployment exposes formal generated-audio configuration: provider mode `dashscope`, model `qwen-audio-3.0-tts-flash`, voice `loongeva_v3.6`, provider profile `qa-formal-v1`, and voice version `generated-tts-v1`. These are public deployment settings, not Secret values. No Secret value was read or recorded.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran once, serially, for `1472.7` seconds and returned exit code `0` with zero violations. Every manifest receipt remained `PASS`; no `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted.

- `complete_bundle`: PASS.
- `activation_safety_repair`: PASS.
- `legacy_quarantine`: PASS.
- `recovery_coordinator`: PASS.
- `handoff_confirmation`: PASS.
- `backend_real_tts`: PASS.
- `mobile_formal_audio`: PASS.
- `garden_today_continuity`: PASS.
- `privacy`: PASS.
- `static_source`: PASS.
- `release_evidence_schema`: PASS.
- `clean_worktree`: PASS.
- `full_ci`: PASS.

Full CI ran from verification HEAD `5078e58dde5f827da03241702f3122a558159d8a`. The frozen backend source is an ancestor of that candidate. The machine Gate covers formal provider code, focused contracts, privacy/static checks, and full repository CI. It does not replace human Android execution, actual TalkBack hearing, human-heard audio review, or the #56 device reopen check.

After the aggregate completed, the #39 verifier test passed `21/21`. The standalone practice-generation privacy verifier, M2-11 privacy/architecture verifier, Spring AI 2 static-source verifier, and `git diff --check` also passed against the tracked evidence change.

## UAT boundary

The manifest is the only allowed input to final UAT. A post-build device attempt recorded on #56 ended with the sanitized terminal state `generation_unavailable`, so it did not produce a new ready intent for the device reopen check. That outcome does not support a human or device PASS claim and is not reinterpreted here. Issue #40, issue #53, issue #56, and release closure remain open until their same-tuple requirements pass.

No raw scene, prompt, provider request/response, utterance body, audio bytes, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
