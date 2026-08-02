# GitHub #44 rev47 live acceptance

Candidate: `98dd07528c768e4b88e0d259a5915e33a5e89715`, image tag `m2-98dd0752`, Helm app revision 47, infra revision 42.

Verdict: **PASS**. One fresh real-provider request reached ACTIVE with six approved utterances.

- Baseline counts: `6/8/13/13` for content / attempts / operations / provider calls.
- Terminal counts: `7/9/15/15`.
- Generator and Quality Judge completed successfully.
- Attempt 1 completed with `passed`; Repair was not required.
- No `DATABASE_OVERFLOW` or field-bound violation occurred.
- Exactly one content identity and one attempt were created.
- Reconciliation and repeated open attempts did not add content, attempts, operations, or provider calls.

The focused contract/schema/validator/orchestrator tests and privacy-safe diagnostics were delivered upstream. This run supplies the missing post-deployment ACTIVE six-utterance gate. GitHub #48 owns the unrelated Android navigation failure after activation.

No raw generated field, prompt, payload, private identifier, token, hash reference, or secret is stored.
