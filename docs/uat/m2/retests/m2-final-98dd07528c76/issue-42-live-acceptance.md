# GitHub #42 rev47 live acceptance

Candidate: `98dd07528c768e4b88e0d259a5915e33a5e89715`, image tag `m2-98dd0752`, app-api image identity `sha256:e23debc98efc9d5f79dd9005b692876c1152d28ce992f9a768a5e8402e27fc0d`, Helm app revision 47, infra revision 42.

Verdict: **PASS**. One fresh authorized Android request reached one ACTIVE Complete Bundle through the formal real-provider path.

- Baseline counts: `6/8/13/13` for content / attempts / operations / provider calls.
- Terminal counts: `7/9/15/15`.
- Exactly one content identity and one attempt were added.
- Generator operation/provider: `completed / succeeded`; provider latency `103257 ms`.
- Quality Judge operation/provider: `completed / succeeded`; provider latency `111228 ms`.
- Attempt 1: `completed / passed`.
- Content terminal: `active`.
- Approved utterance count: `6`.
- Same-identity reconciliation and repeated open attempts kept counts at `7/9/15/15`.

Provider operation and call states distinguish the successful Generator and Judge terminals. Earlier focused verifiers and backend gates remain part of the implementation evidence; this run supplies the missing fresh ACTIVE live gate and freezes the backend candidate before UAT resumes.

Android presentation is not claimed here. Automatic handoff and manual reopen exposed the separate mobile navigation defect tracked by GitHub #48.

No prompt, provider body, generated text, private identifier, owner hash, token, secret, or raw error is stored.
