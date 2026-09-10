# GitHub #42 rev42 live acceptance

Candidate: `4b856f22cefa9272da5646e4493950a5b3bd2aa7`, image tag `m2-4b856f22`, Helm app revision 42, infra revision 37.

Verdict: **FAIL**. One authorized Android request did not reach an ACTIVE Complete Bundle.

- Request count: exactly one new content identity and one generation attempt.
- Recovery: one same-identity reconciliation; aggregate counts stayed `3/3/5/5`.
- Generation terminal: `rejected / generation_invalid_output / non-retryable`.
- Attempt terminal: `completed / terminal_violation`.
- Sanitized violations: `DATABASE_OVERFLOW`, `no_response:DATABASE_OVERFLOW`, `resisting:DATABASE_OVERFLOW`.
- Provider terminal: `dashscope-qwen / openai-compatible / glm-5.2 / fallback_0 / succeeded`.
- Operation terminal: `generator / completed / succeeded`.
- Android terminal: generation-ended state rendered; no typed bundle.

Privacy-safe overflow evidence is limited to branch-role violation codes. Rejected candidate values were not persisted. Actual overlong field names and lengths therefore cannot be recovered without prohibited raw provider content. Static storage limits enforced by the validator are:

- `space_title_zh`, `activity_title_zh`, `scene_tag_en`, `english_text`, `chinese_text`, `pronunciation_hint`: 120 code points.
- `tpr_action_zh`, `delivery_guidance_zh`: 240 code points.
- `difficulty`: 16 code points.
- `generation_source`: 32 code points.

This proves provider transport success and deterministic terminal rejection, but not the exact overflowing field. GitHub #42 acceptance remains unmet; #40 cannot proceed beyond response-loss reconciliation on this candidate.
