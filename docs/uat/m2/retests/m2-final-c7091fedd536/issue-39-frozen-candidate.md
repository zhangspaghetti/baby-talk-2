# Issue #39 frozen final candidate after #55 and formal DashScope audio

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 still requires final no-code human Android/TalkBack sign-off on this exact candidate. Issue #53 still requires final human confirmation that starter and all five reaction branches are audible and match the displayed text. No `HUMAN_ANDROID` result or human-heard audio result is claimed here.

## Immutable candidate

- Candidate ID: `m2-final-c7091fedd536`.
- Mobile source: `c7091fedd536e473707c47b6658ed80d6ea2d791`.
- APK SHA-256: `fd4ddd608e22dc9235aff081413e6a2311ab582e37d7e8ad6a5e8159e737ec3c`.
- APK size: `171585283` bytes.
- Backend source: `0f79f451bd821ba94815885d130585757d7b8005`.
- Backend artifact: `image_sha256:8e19c186c92e3683fd64a77cdbeb89871afd9223cf948760cc14e1a6b29093ec`.
- Environment: `sanitized-qa-kind-rev5`.
- Release generation provider mode/profile: `real` / `qa-dashscope-qwen`.
- Generation model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:072195c3c7b4ba0fe98278c94cc5cfd2c67e435294783ac4ade72ad951c28435`.
- Frozen manifest: `artifacts/m2-final-c7091fedd536-20260809.json`.
- Manifest SHA-256: `ee3fab938bd048f08dc018d4205205b382b1f44d508d36fd31fed439c278d4d1`.

This tuple supersedes `m2-final-31203b1b1f61`. The mobile source and APK changed through the subsequent UAT defect fixes. The deployed backend also changed to the formal DashScope generated-audio implementation.

## Live QA deployment identity

Read-only checks after the Gate run confirmed `babytalk-qa-app` Helm revision `5` remains `deployed`. The live app-api Pod is ready with zero restarts, uses immutable tag `babytalk/app-api:m2-0f79f451`, and reports image ID `sha256:8e19c186c92e3683fd64a77cdbeb89871afd9223cf948760cc14e1a6b29093ec`. The tag resolves unambiguously in repository history to backend source `0f79f451bd821ba94815885d130585757d7b8005`, which is an ancestor of the mobile candidate.

The live non-secret practice-AI ConfigMap selects the agentic path through `dashscope-qwen` with model `glm-5.2`. SHA-256 of the exact UTF-8 model name is:

`bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`

No runtime override replaces the backend's version-locked default profile. At backend source `0f79f451bd821ba94815885d130585757d7b8005`, the sanitized source/profile/prompt-version tuple is:

`0f79f451bd821ba94815885d130585757d7b8005|custom-scene-generation-v6|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

SHA-256 over that exact UTF-8 string, with no surrounding whitespace or final newline, is `072195c3c7b4ba0fe98278c94cc5cfd2c67e435294783ac4ade72ad951c28435`.

The same live app-api deployment exposes the formal generated-audio configuration: provider mode `dashscope`, model `qwen-audio-3.0-tts-flash`, voice `loongeva_v3.6`, provider profile `qa-formal-v1`, and voice version `generated-tts-v1`. These are public deployment settings, not Secret values. The manifest's singular provider model identity continues to identify the generated-content model required by the M2 candidate schema; the backend artifact and documented live audio settings pin the TTS implementation and runtime configuration.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran for `672.0` seconds and returned exit code `0` with zero violations. Every manifest receipt remained `PASS`; no `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted.

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

Full CI ran from verification HEAD `c7091fedd536e473707c47b6658ed80d6ea2d791`. The frozen backend source is an ancestor of that candidate. The machine Gate covers formal provider code, focused contracts, privacy/static checks, and full repository CI. It does not replace human Android execution or human-heard audio review.

After the aggregate completed, the #39 verifier test passed `21/21`. The standalone practice-generation privacy verifier, M2-11 privacy/architecture verifier, Spring AI 2 static-source verifier, and `git diff --check` also passed against the tracked evidence change.

## UAT boundary

The manifest is the only allowed input to final UAT. Candidate freeze does not complete #40 or #53. Actual TalkBack speech, touch exploration, gesture order, focus return, audio audibility, and confirmation that each of the six audio branches matches its displayed text require explicit human observation on this exact tuple. Until those same-tuple records are final `PASS`, release closure remains `NOT COMPLETE` and #28 must remain open.

No raw scene, prompt, provider request/response, utterance body, audio bytes, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
