# Issue #39 frozen final candidate after #50

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 remains a no-code human Android/TalkBack sign-off and has not been executed for this candidate. No `HUMAN_ANDROID` result is claimed here.

## Immutable candidate

- Candidate ID: `m2-final-31203b1b1f61`.
- Mobile source: `31203b1b1f6199f017167c8d4f8467393452e42d`.
- Installed APK SHA-256: `cf565b39b8d8e58e4f33d516ab21bcadafe57c65744889f63211961b872053ff`.
- Installed APK size: `171561603` bytes.
- Backend source: `98dd07528c768e4b88e0d259a5915e33a5e89715`.
- Backend artifact: `image_sha256:e23debc98efc9d5f79dd9005b692876c1152d28ce992f9a768a5e8402e27fc0d`.
- Environment: `sanitized-qa-kind-rev1`.
- Release provider mode/profile: `real` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:9cd438e1c5a003a1636a6ddcd711a2ce67f309e47831d55aa379090b2e91fd42`.
- Frozen manifest: `artifacts/m2-final-31203b1b1f61-20260808.json`.
- Manifest SHA-256: `e2e1df163557e99f3a6ab243b9fdfcf6255c89033c8caa643e99de2a1c4faea9`.

This tuple supersedes `m2-final-b89c8433c47d`; #50 changed the mobile source and APK. Backend source and deployed app-api artifact remain unchanged.

## Deployment and provider identity

Read-only deployment checks confirmed `babytalk-qa-app` Helm revision `1` remains `deployed`, and the live app-api container image ID remains `sha256:e23debc98efc9d5f79dd9005b692876c1152d28ce992f9a768a5e8402e27fc0d`.

Non-secret QA Helm values select the real agentic path through `dashscope-qwen` with model `glm-5.2`. SHA-256 of the exact UTF-8 model name is:

`bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`

The version-locked backend profile at the frozen backend source resolves the sanitized source/profile/prompt-version tuple to:

`98dd07528c768e4b88e0d259a5915e33a5e89715|custom-scene-generation-v5|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

SHA-256 over that exact UTF-8 string, with no surrounding whitespace or final newline, is `9cd438e1c5a003a1636a6ddcd711a2ce67f309e47831d55aa379090b2e91fd42`. Secrets, Kubernetes Secret values, raw prompts, provider bodies, private identifiers, and user content are excluded.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran for 561.4 seconds and returned exit code 0 with zero violations. Every manifest receipt remained `PASS`; no `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted.

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

Full CI ran from mobile source `31203b1b1f6199f017167c8d4f8467393452e42d`, so #50's confirmed cancel/restart path and focused tests are part of the frozen machine-tested candidate.

## UAT boundary

The manifest is the only allowed input to final UAT. Candidate freeze does not substitute for #40. Actual TalkBack speech, audio audibility, gesture order, failure/cancel/restart behavior, error/retry announcements, and focus return require explicit human observation on this exact tuple. Until all five same-tuple `HUMAN_ANDROID` records pass, #40 and #28 remain open.

No raw scene, prompt, provider request/response, utterance body, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
