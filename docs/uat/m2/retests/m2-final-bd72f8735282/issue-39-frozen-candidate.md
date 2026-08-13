# Issue #39 frozen candidate for emulator audio UAT

Candidate freeze verdict: **PASS**.

Release closure verdict: **NOT COMPLETE**. Issue #40 remains open. This freeze creates no `HUMAN_ANDROID` record and makes no human-heard audio or TalkBack claim.

## Immutable candidate

- Candidate ID: `m2-final-bd72f8735282`.
- Mobile source: `bd72f8735282455bf7da218dedd776b87ffd1229`.
- Emulator-installed APK SHA-256: `77dbe2336ccb5b695e54f2dd9d13991cb96416545b2482b65b185cdfdd91e57c`.
- Emulator-installed APK size: `198910363` bytes.
- Backend source: `dd71582a1093256421d3ec369cd3bf4b6a2b03da`.
- Backend artifact: `image_sha256:c7d7554496dc34f3f7bd75315684076541d34baf1b3cc566fb5e1135270ce347`.
- Environment: `sanitized-qa-kind-rev12`.
- Provider mode/profile: `real` / `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.
- Configuration fingerprint: `sha256:d35afa0c260c2703d29336daea38315b26f8fed54835188139ae7ade188f84fb`.
- Ignored manifest: `artifacts/m2-final-bd72f8735282-20260813.json`.
- Manifest SHA-256: `83623ad037a15663721c945b856bb800d69812649e2f832f61a206143d5646bc`.
- Manifest size: `3157` bytes.

The APK was built fresh from the frozen mobile source with the canonical QA defines, installed specifically on `emulator-5554`, and pulled back for byte-for-byte verification. Local and installed SHA-256 and byte counts match. The QA backend remains healthy at Helm revision 12 with the verified backend ancestor.

## Closure Gate aggregate

The formal M2-13 verifier ran once, serially, on the ignored manifest. It completed in `1447.7` seconds with exit code `0`, all 13 receipts `PASS`, zero violations, and the success marker `M2-13 final candidate is frozen for UAT.`

## UAT boundary

The ignored manifest is the only allowed input for subsequent UAT. The existing UAT1-UAT3 records belong to the superseded candidate and remain historical evidence; they cannot satisfy closure for this tuple. UAT4 and UAT5 remain pending. This freeze does not start either case.

No raw scene, prompt, utterance, provider payload, audio bytes, account, phone, device serial, request identity, credential, token, Secret value, screenshot, or private evidence is stored.
