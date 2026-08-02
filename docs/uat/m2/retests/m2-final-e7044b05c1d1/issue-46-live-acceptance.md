# GitHub #46 rev44 live acceptance

Candidate: `e7044b05c1d10572f3335d6999b91517a7bb73c7`, image tag `m2-e7044b05`, Helm app revision 44, infra revision 39.

Verdict: **FAIL**. One authorized Android request did not reach an ACTIVE Complete Bundle.

- Baseline counts: `4/5/9/9` for content / attempts / operations / provider calls.
- Terminal counts: `5/6/11/11`.
- Recovery: one same-identity reconciliation; counts stayed `5/6/11/11`.
- Generator: `completed / succeeded`; provider `succeeded`; latency `112597 ms`.
- Quality Judge: `completed / providers_exhausted`; provider `output_truncated`; latency `149398 ms`.
- Content terminal: `expired / generation_unavailable`.
- Android terminal: generation-ended state rendered; no typed bundle.

GitHub #46 owns the Quality Judge structured-output truncation. This candidate did not reach Judge verdict evaluation or Repair, so GitHub #45's evidence/action-consistency fix was not exercised. GitHub #45, #44, and #42 remain open because fresh `ACTIVE` acceptance is still unmet. #40 cannot proceed beyond response-loss reconciliation on this candidate.

The configuration fingerprint is SHA-256 over the sanitized candidate descriptor `candidate + profile version + Generator version + Repair version + Judge version`; it excludes secrets and private identifiers.

No raw provider request/response body, user-entered scene, private identifier, owner hash, token, or secret is stored in this evidence set.
