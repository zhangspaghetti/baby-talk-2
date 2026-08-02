# GitHub #45 rev43 live acceptance

Candidate: `9beba11f856eaf01ba44d1c06f980eecbbec4e88`, image tag `m2-9beba11f`, Helm app revision 43, infra revision 38.

Verdict: **FAIL**. One authorized Android request did not reach an ACTIVE Complete Bundle.

- Baseline counts: `3/3/5/5` for content / attempts / operations / provider calls.
- Terminal counts: `4/5/9/9`.
- Recovery: one same-identity reconciliation; counts stayed `4/5/9/9`.
- Generator: `completed / judge_repair / TPR_QUALITY_FAILED`.
- Repair: `completed / attempt_limit_exhausted / judge_evidence_action_inconsistent / TPR_QUALITY_FAILED`.
- Content terminal: `rejected / generation_invalid_output`.
- Android terminal: generation-ended state rendered; no typed bundle.

The previous `DATABASE_OVERFLOW` failure did not recur. The remaining blocker is the repaired bundle's Judge evidence/action consistency. GitHub #45 owns that defect. GitHub #44 and #42 remain open because fresh `ACTIVE` acceptance is still unmet; #40 cannot proceed beyond response-loss reconciliation on this candidate.

No raw provider request/response body, user-entered scene, private identifier, owner hash, token, or secret is stored in this evidence set.
