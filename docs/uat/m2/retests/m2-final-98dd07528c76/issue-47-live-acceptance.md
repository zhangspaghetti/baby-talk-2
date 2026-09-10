# GitHub #47 rev47 live acceptance

Candidate: `98dd07528c768e4b88e0d259a5915e33a5e89715`, image tag `m2-98dd0752`, Helm app revision 47, infra revision 42.

Verdict: **PARTIAL — KEEP OPEN**.

- Generator completed successfully.
- Attempt 1 passed directly.
- Repair was not invoked.
- Real Quality Judge completed successfully.
- Content reached ACTIVE with six approved utterances.
- Counts changed once from `6/8/13/13` to `7/9/15/15`; reconciliation and open retries kept counts unchanged.

The code regression proves the old truncated Repair completion and the v5 bounded compatibility behavior. This live candidate did not exercise Repair, so GitHub #47's explicit `Repair completion and then a real Quality Judge terminal verdict` acceptance remains unmet.

No prompt, provider body, generated text, private identifier, owner hash, token, secret, or raw error is stored.
