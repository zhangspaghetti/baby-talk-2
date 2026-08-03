# Issue #47 live acceptance

Verdict: **PASS**.

## Candidate

- Backend source: `98dd07528c768e4b88e0d259a5915e33a5e89715`.
- Backend artifact: `image_sha256:e23debc98efc9d5f79dd9005b692876c1152d28ce992f9a768a5e8402e27fc0d`.
- Environment: `sanitized-qa-kind-rev47`.
- Provider mode: `REAL`.
- Provider profile: `qa-dashscope-qwen`.
- Provider model identity: `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.

## Sanitized live result

- One fresh canonical bath request was submitted once.
- Aggregate counts changed from `7/9/15/15` to `8/10/16/16` when the request began, then reached terminal `8/11/19/19` after the bounded Repair and final Judge path.
- Attempt 1: Generator completed; Judge requested repair.
- Attempt 2: Repair completed; final Judge passed.
- Generator, Repair, and both Judge operation/provider paths completed successfully.
- Content reached ACTIVE with exactly six approved utterances.
- No prompt, scene text, utterance body, provider payload, private identifier, credential, or token is stored here.

This supplies the live real-provider Repair-then-Judge acceptance that was missing from the earlier discovery record.
