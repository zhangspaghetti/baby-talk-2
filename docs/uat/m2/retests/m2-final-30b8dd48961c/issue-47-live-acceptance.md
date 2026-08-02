# GitHub #47 rev46 live acceptance

Candidate: `30b8dd48961c4108ce60978eab664f949480aa4a`, image tag `m2-30b8dd48`, Helm app revision 46, infra revision 41.

Verdict: **FAIL**. One authorized Android request did not reach an ACTIVE Complete Bundle.

- Baseline counts: `5/6/11/11` for content / attempts / operations / provider calls.
- Terminal counts: `6/8/13/13`.
- Recovery: one same-identity reconciliation; counts stayed `6/8/13/13`.
- Generator: `completed / succeeded`; provider `succeeded`; latency `114380 ms`.
- Attempt 1: `completed / repairable_violation`.
- Repair: `completed / providers_exhausted`; provider `output_truncated`; latency `131152 ms`.
- Content terminal: `expired / generation_unavailable`.
- Android terminal: generation-ended state rendered; no typed bundle.

GitHub #47 owns the Repair structured-output truncation. This candidate did not reach Quality Judge, so GitHub #46's Judge truncation fix and GitHub #45's evidence/action-consistency acceptance were not exercised. GitHub #47, #46, #45, #44, and #42 remain open because fresh `ACTIVE` acceptance is still unmet. #40 cannot proceed beyond response-loss reconciliation on this candidate.

The configuration fingerprint is SHA-256 over the sanitized candidate descriptor `candidate + profile version + Generator version + Repair version + Judge version`; it excludes secrets and private identifiers.

No raw provider request/response body, user-entered scene, private identifier, owner hash, token, or secret is stored in this evidence set.
