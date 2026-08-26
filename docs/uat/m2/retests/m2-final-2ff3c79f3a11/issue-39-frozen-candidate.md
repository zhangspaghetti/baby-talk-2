# M2 final candidate freeze — `m2-final-2ff3c79f3a11`

Candidate freeze: **PASS**.

Release closure: **NOT COMPLETE**. This report records automated evidence only. No `HUMAN_ANDROID` record, human-heard audio result, or TalkBack sign-off is claimed.

## Immutable tuple

- Candidate ID: `m2-final-2ff3c79f3a11`.
- Mobile source SHA: `2ff3c79f3a1149f831bc22b1f0c4d36bb1484c7f`.
- APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`; SHA-256 `72535a69baaf3a42de29fd2577300c03a055f40c9f6cadc6efd5ee36c819d093`; `172070992` bytes.
- Installed APK artifact: `artifacts/m2-final-2ff3c79f3a11-installed.apk`; same SHA-256 and byte count.
- Backend source SHA: `2ff3c79f3a1149f831bc22b1f0c4d36bb1484c7f`.
- Deployed app-api artifact: `image_sha256:159831b5f9f645d7d46fa5e8e037bba9f4b2f366cf8a10e93f6b9e64a12e6975` (current Pod image ID).
- Environment: `sanitized-qa-kind-rev26`.
- Provider: `real` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:1f79797d298605479f2b27347eff87ea4629cdf72e7cc78faa1752cc18482d33`.
- Mobile release Dart-define fingerprint: `sha256:2d12a9228dd28dfdb659e00cfc9336605acabc772bd2d30eea40a5aefee8b364`; custom-scene entry: `true`.
- Ignored candidate manifest: `artifacts/m2-final-2ff3c79f3a11/candidate-manifest.json`; SHA-256 `280a8e4db8cb5f621d3902c0d4ed3091d3d1b7a16f91377a95b4e946f53a9357`; `2782` bytes.

The configuration fingerprint is SHA-256 of the exact UTF-8 string:

`2ff3c79f3a1149f831bc22b1f0c4d36bb1484c7f|custom-scene-generation-v7|custom-scene-generator-v3|custom-scene-repair-v4|custom-scene-quality-judge-v3`

## Deployment proof

QA was deployed from the candidate-tagged images with `QA_CANDIDATE_ID=m2-final-2ff3c79f3a11` and required migration `36`.

- Helm `babytalk-qa-app`: revision `26`, `deployed`.
- Helm `babytalk-qa-infra`: revision `18`, `deployed`.
- `gateway`, `admin-api`, `admin-web`, and `app-api`: all `Ready=true`, zero application restarts.
- Current app-api Pod image ID matches the tuple above.
- Gateway candidate compatibility: `compatible`.

## M2-13 closure gates

Command:

`dart tool/verify_m2_13_closure_candidate.dart --manifest artifacts/m2-final-2ff3c79f3a11/candidate-manifest.json`

Exit code `0`; `m2_13_closure_candidate_status=pass`; `violations=0`; marker: `M2-13 final candidate is frozen for UAT.`

All 13 receipts in the manifest are `PASS`: `complete_bundle`, `activation_safety_repair`, `legacy_quarantine`, `recovery_coordinator`, `handoff_confirmation`, `backend_real_tts`, `mobile_formal_audio`, `garden_today_continuity`, `privacy`, `static_source`, `release_evidence_schema`, `clean_worktree`, and `full_ci`.

## Automated live provider/audio evidence

Privacy-safe evidence is in [`live-generated-audio-evidence.json`](../../../../../artifacts/m2-final-2ff3c79f3a11/live-generated-audio-evidence.json), SHA-256 `21e3b7a9a2539225709166b5cfb1e3092ceaae76b694634de2d1e502f52328be`, `3057` bytes.

One authenticated `care_path/custom_scene` request on the deployed candidate returned `200` with `source=generated`, one scene, one moment, six utterances, and all five canonical reaction branches. Provider provenance was present for all six rows (`provider_repaired`, attempt `2`, provider `dashscope-qwen`, model `glm-5.2`). A replay with the same client request returned `200`, the same generated-content identity, and the same bundle shape; no second generation request was created.

Each of the six approved utterances was fetched through the formal audio endpoint. All returned HTTP `200`, non-empty `audio/mpeg`, `Cache-Control: no-store, private`, provider `dashscope`, model `qwen-audio-3.0-tts-flash`, profile `qa-formal-v1`, and the same configuration fingerprint. Raw scene text, provider payloads, utterance text, and audio bytes were not stored.

## Human boundary / shortest remaining checklist

1. Verify the manifest, APK SHA-256, byte count, and candidate ID in About on the designated Android device; install exactly this APK.
2. With the approved canonical scene, exercise starter plus all five reactions; a human must listen to every generated MP3 and record audible result. Repeat after process force-stop/relaunch; confirm Today/Garden reopen the same generated Care Turn without a new generation.
3. Enable TalkBack and traverse entry, starter, reaction choices, audio controls, retry/reopen, Today, and Garden. Confirm spoken labels, focus order, and activation by touch/TalkBack.
4. Write a `HUMAN_ANDROID` record bound to this exact candidate ID/SHA/bytes. Until that record exists, keep #15, #28, #40, #53, and the human portion of #56 open.

No raw content, credentials, Secret values, account/phone/device identifiers, screenshots, or human accessibility/audio claims are stored here.
