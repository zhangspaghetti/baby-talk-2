# Issue #39 frozen final candidate after #58 and #59 mobile fixes

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 still requires final no-code human Android/TalkBack sign-off on this exact candidate. Issue #53 still requires human confirmation that the starter and all five reaction branches are audible and match displayed text. Issue #58 remains open for its frozen-candidate two-cold-start draft-expiry device acceptance, and its dependent #56 reopen acceptance is not complete. No `HUMAN_ANDROID`, human-heard audio, TalkBack, draft-expiry, or prepared-content reopen PASS is claimed here.

## Immutable candidate

- Candidate ID: `m2-final-d8e79613eb1a`.
- Mobile source: `d8e79613eb1a95561479a99139611cd4a1d4023a`.
- APK SHA-256: `118afe1b413fb64be3a2afbed378937cef0b4ba30a4d6b4b0daa816007b56c46`.
- APK size: `171586315` bytes.
- Backend source: `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`.
- Backend artifact: `image_sha256:7ac4094dfb8c777a1d09fec7968ab468cf3df052b210ac4e4a9fbb5fa48e0e55`.
- Environment: `sanitized-qa-kind-rev9`.
- Release generation provider mode/profile: `real` / `qa-dashscope-qwen`.
- Generation model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:355b305943af839770e7e2ad71a53da5869d20d537b01d281367c9ac003eeec0`.
- Frozen manifest: `artifacts/m2-final-d8e79613eb1a-20260811.json`.
- Manifest SHA-256: `7fdfd6ba773ff559423b494ecf54d6bd53f44d3369c825573a47e1c551eebd10`.

This tuple supersedes `m2-final-9d5b636ad0a3`. The backend source, deployed artifact, environment, provider identity, and version-locked public configuration remain unchanged. The mobile source and APK identity changed through the #58 draft-expiry and #59 signed-out seed-directory fixes. Git ancestry independently proves the backend source is an ancestor of the mobile source, and the mobile source equals verification `HEAD`.

The local release APK and the APK pulled from the test emulator both have the exact SHA-256 and byte count above. No account, device, installation, or package-path identifier is recorded.

## Live QA deployment identity

Read-only checks before and after the Gate run confirmed `babytalk-qa-app` Helm revision `9` remains `deployed`. All four application Deployments and their current Pods specify immutable tag `m2-9d5b636a`, are ready, and have zero restarts. The live app-api Pod reports image ID `sha256:7ac4094dfb8c777a1d09fec7968ab468cf3df052b210ac4e4a9fbb5fa48e0e55`.

The live non-Secret Practice AI ConfigMap selects the agentic path through `dashscope-qwen` with provider type `openai-compatible` and model `glm-5.2`. Generator, repair, and Quality Judge routes all select that provider. No runtime override replaces the backend's version-locked default profile. At backend source `9d5b636ad0a36a3bd4482acc42b768076fb7fe3b`, the canonical source/profile/prompt-version tuple is:

`9d5b636ad0a36a3bd4482acc42b768076fb7fe3b|custom-scene-generation-v7|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

SHA-256 over that exact UTF-8 string, with no surrounding whitespace or final newline, is `355b305943af839770e7e2ad71a53da5869d20d537b01d281367c9ac003eeec0`.

The same live app-api deployment exposes formal generated-audio configuration: provider mode `dashscope`, model `qwen-audio-3.0-tts-flash`, voice `loongeva_v3.6`, provider profile `qa-formal-v1`, and voice version `generated-tts-v1`. These are public deployment settings. No Secret resource or value was read or recorded, and `helm status -o json` was not used.

## Formal provider machine boundary

The unchanged backend artifact and QA revision retain the previously accepted #57 operational evidence: one normal Android submission reached one successful Generator provider call and one successful Quality Judge provider call, produced one active six-utterance Bundle, and reconciliation did not increase outbound count. This re-freeze issued no new provider request and does not reinterpret that machine evidence as human behavior.

The new mobile changes affect expired draft restoration and signed-out seed-directory behavior only. Full CI and focused closure Gates ran from mobile verification `HEAD` while the manifest independently pins the unchanged backend runtime source and artifact.

## Closure Gate aggregate

The formal M2-13 closure-candidate verifier ran once, serially, for `1116.2` seconds and returned exit code `0` with zero violations. Every manifest receipt remained `PASS`; no `FAIL`, `BLOCKED`, or `NOT RUN` status was reinterpreted.

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

Full CI ran from verification HEAD `d8e79613eb1a95561479a99139611cd4a1d4023a`. The formal run began with a clean tracked worktree; the manifest is ignored. The machine Gate covers formal provider code, focused contracts, privacy/static checks, and full repository CI. It does not replace human UAT.

After the aggregate, the #39 verifier test, standalone practice-generation privacy verifier, M2-11 privacy/architecture verifier, and Spring AI 2 static-source verifier passed. Because both evidence files were still untracked, each file separately passed the equivalent `git -c core.autocrlf=false diff --no-index --check NUL <file>` whitespace check; no empty tracked diff was used as evidence.

## UAT boundary

The manifest is the only allowed input to final UAT. No `HUMAN_ANDROID` JSON record was created during this freeze. Issue #40 remains open and no-code. Issue #53 remains open for human-heard audio review. Issue #58 remains open for frozen-candidate device acceptance; #56 remains incomplete behind that acceptance. Issue #28 remains open until every required upstream ticket and final sign-off pass on the same frozen tuple.

No raw scene, prompt, provider request/response, utterance body, audio bytes, account, device, request identity, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
