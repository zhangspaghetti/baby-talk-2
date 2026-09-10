# Issue #39 frozen final candidate

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 remains open, and no complete five-case `HUMAN_ANDROID` release matrix exists for this candidate.

## Immutable candidate

- Candidate ID: `m2-final-ad2c9ceeefff`.
- Mobile source: `ad2c9ceeefff1b8eca8358d6c423268cbff2d55c`.
- Installed APK SHA-256: `9c492bd547b462b28b15490e5cc9c0fd40575e0a2aef88097684bc7b53b0e9bd`.
- Backend source: `98dd07528c768e4b88e0d259a5915e33a5e89715`.
- Backend artifact: `image_sha256:e23debc98efc9d5f79dd9005b692876c1152d28ce992f9a768a5e8402e27fc0d`.
- Environment: `sanitized-qa-kind-rev47`.
- Provider mode/profile: `REAL` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:9cd438e1c5a003a1636a6ddcd711a2ce67f309e47831d55aa379090b2e91fd42`.
- Frozen manifest: `artifacts/m2-final-ad2c9ceeefff-20260803.json`.

## Configuration fingerprint

Repository evidence defines this as SHA-256 over the sanitized source/profile/prompt-version tuple. The version-locked rev47 profile resolves that tuple to:

`98dd07528c768e4b88e0d259a5915e33a5e89715|custom-scene-generation-v5|custom-scene-generator-v3|custom-scene-repair-v3|custom-scene-quality-judge-v3`

Algorithm: encode the exact pipe-delimited string as UTF-8 with no leading/trailing whitespace or final newline, compute SHA-256, render lowercase hexadecimal, and prefix `sha256:`. Result matches the configuration fingerprint already recorded in rev47 sanitized discovery evidence. Secrets, Kubernetes Secret values, raw prompts, private identifiers, and provider bodies are excluded.

## Reviewed closure gates

- #30 Complete Bundle: PASS.
- #31 activation, safety, Repair, Judge: PASS. Final live Repair-then-Judge path reached ACTIVE.
- #32 legacy quarantine: PASS.
- #33 recovery coordinator: PASS.
- #34 handoff confirmation: PASS.
- #35 backend real TTS: PASS.
- #36 mobile formal audio: PASS.
- #37 Garden/Today continuity: PASS.
- #38 release-evidence schema/verifier implementation: PASS.
- #47 live Repair completion then real Judge terminal verdict: PASS and closed.
- #48 handoff, retry, force-stop recovery, and formal six-utterance rendering: PASS and closed.
- Flutter full suite: `795/795`; `flutter analyze`: PASS.
- QA aggregate counts: content/attempts/operations/provider calls `8/11/19/19`; latest content ACTIVE with six approved utterances.
- Candidate worktree/CI evidence: PASS. The formal M2-13 closure-candidate verifier completed on a clean worktree after the #38 split-source correction.

All manifest Gate receipts remain `PASS`; no `FAIL`, `BLOCKED`, or `NOT RUN` result is reinterpreted.

## Verifier boundary

Manifest structural validation passes with zero violations. The #38 split-source verifier defect was corrected in `488084ea`: both source SHAs must resolve to immutable commits, mobile must be an ancestor of checked-out HEAD, and backend must be an ancestor of mobile. The formal #39 Gate rerun completed with `m2_13_closure_candidate_status=pass` and zero violations.

#40 remains independently incomplete. The #38 release-matrix verifier correctly fails for this candidate until five privacy-safe, same-tuple, final `PASS` `HUMAN_ANDROID` records exist, including actual TalkBack observations. Candidate freeze success does not claim release closure.

No raw scene, prompt, provider request/response, utterance body, private identifier, credential, token, Secret value, screenshot, or private evidence is stored.
