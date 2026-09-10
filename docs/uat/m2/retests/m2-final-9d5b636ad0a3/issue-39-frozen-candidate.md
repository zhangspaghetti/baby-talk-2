# Issue #39 frozen final candidate after #57 Quality Judge inference-policy fix

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 still requires final no-code human Android/TalkBack sign-off on this exact candidate. Issue #53 still requires final human confirmation that the starter and all five reaction branches are audible and match displayed text. Issue #56 still requires its frozen-candidate device reopen check. No `HUMAN_ANDROID`, human-heard audio, or device reopen PASS is claimed here.

## Immutable candidate

- Candidate ID: `m2-final-9d5b636ad0a3`.
- Mobile source: `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`.
- APK SHA-256: `8f785581b14afff57f3185b1dec8cf2943e1654c785ff8bdd663ce1bd5421276`.
- APK size: `171586151` bytes.
- Backend source: `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`.
- Backend artifact: `image_sha256:7ac4094dfb8c777a1d09fec7968ab468cf3df052b210ac4e4a9fbb5fa48e0e55`.
- Environment: `sanitized-qa-kind-rev9`.
- Release generation provider mode/profile: `real` / `qa-dashscope-qwen`.
- Generation model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:355b305943af839770e7e2ad71a53da5869d20d537b01d281367c9ac003eeec0`.
- Frozen manifest: `artifacts/m2-final-9d5b636ad0a3-20260810.json`.
- Manifest SHA-256: `759c72c90681e73902839486094ede7872f991f0a8f376fdcfbad17c3baa0f5c`.

This tuple supersedes `m2-final-5078e58dde5f`. Source, deployed backend artifact, environment, and version-locked public configuration changed through the #57 Quality Judge inference-policy fix. APK bytes are unchanged because no mobile source changed after its previous build; local and installed test-emulator APK identities still match exactly.

## Live QA deployment identity

Read-only checks before and after the Gate run confirmed `babytalk-qa-app` Helm revision `9` remains `deployed`. All four application Deployments and their current Pods specify immutable tag `m2-9d5b636a`, are ready, and have zero restarts. The live app-api Pod reports image ID `sha256:7ac4094dfb8c777a1d09fec7968ab468cf3df052b210ac4e4a9fbb5fa48e0e55`.

The live non-secret practice-AI ConfigMap selects the agentic path through `dashscope-qwen` with model `glm-5.2`. SHA-256 of the exact UTF-8 model name is:

`bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`

No runtime override replaces the backend's version-locked default profile. At backend source `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`, the sanitized source/profile/prompt-version tuple is:

`9d5b636ad0a36a3bd4482acc42b768076fb7fe3b|custom-scene-generation-v7|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

SHA-256 over that exact UTF-8 string, with no surrounding whitespace or final newline, is `355b305943af839770e7e2ad71a53da5869d20d537b01d281367c9ac003eeec0`.

Profile v7 sets typed `reasoning-effort: none` policies for the exact `openai-compatible` / `glm-5.2` Generator, Repair, and Quality Judge path. It retains minimum output budgets of `8192` tokens for Complete Bundle generation/repair and Quality Judge output. Older versioned profiles and hashes remain available.

The same live app-api deployment exposes formal generated-audio configuration: provider mode `dashscope`, model `qwen-audio-3.0-tts-flash`, voice `loongeva_v3.6`, provider profile `qa-formal-v1`, and voice version `generated-tts-v1`. These are public deployment settings. No Secret value was read or recorded.

## Formal provider machine evidence

The #57 operational acceptance used one normal Android submission on this deployment. Generator provider completed once in `16003` ms. Quality Judge provider completed once in `2918` ms. Provider outbound count was exactly two and did not increase during reconciliation. The content became active with six approved utterances, and mobile reconciled to ready content without a second identity.

This proves the formal Generator and Quality Judge machine path for the frozen backend artifact. It does not prove human Android behavior, actual TalkBack speech, audio audibility, branch-to-displayed-text agreement, or the #56 reopen interaction.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran once, serially, for `1525.8` seconds and returned exit code `0` with zero violations. Every manifest receipt remained `PASS`; no `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted.

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

Full CI ran from verification HEAD `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`. The machine Gate covers formal provider code, focused contracts, privacy/static checks, and full repository CI. It does not replace human UAT.

After the aggregate completed, the #39 verifier test passed `21/21`. The standalone practice-generation privacy verifier, M2-11 privacy/architecture verifier, Spring AI 2 static-source verifier, and `git diff --check` also passed against the tracked evidence change.

## UAT boundary

The manifest is the only allowed input to final UAT. No `HUMAN_ANDROID` JSON record was created during this freeze. Issue #40 remains open for no-code human execution. Issues #53 and #56 remain open for their device acceptance checks. Machine generation/provider evidence is not reinterpreted as human PASS. Issue #28 remains open until every required upstream ticket and final sign-off pass on the same frozen tuple.

No raw scene, prompt, provider request/response, utterance body, audio bytes, account, device, request identity, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
