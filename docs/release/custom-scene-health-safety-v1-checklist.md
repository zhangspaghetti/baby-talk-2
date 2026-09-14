# Custom-scene health safety v1 release checklist

状态：工程门禁清单。所有勾选项和证据完成前，不得启用生产策略或宣称医疗生产就绪。

## Hard gates

- [ ] Pediatric reviewer approved every signal mapping and all five Chinese templates; reviewer/date/source versions recorded outside runtime logs.
- [ ] v2-capable mobile build is the minimum supported build for custom-scene entry.
- [ ] v1 health request returns no English payload.
- [ ] Epoch-1 content cannot be opened, registered, or synthesized.
- [ ] Fixed corpus: every core health/emergency prompt passes 5/5; all ordinary negative controls match expected outcomes.
- [ ] Rollback target still contains health safety routing; otherwise disable custom-scene generation.

## Evidence to attach

- [ ] Record the pediatric reviewer, review date, reviewed policy/template/source versions, and decision in the release record. Keep these values outside runtime logs and metrics.
- [ ] Attach v1 and v2 HTTP contract results, including Chinese-only health responses and the absence of generated content, English, starter, and audio fields.
- [ ] Attach epoch-1 read, registration, handoff, and audio rejection results.
- [ ] Attach deterministic corpus output with the expected result/template for every acceptance prompt and zero generation/provider calls for health and emergency cases.
- [ ] With fixed provider, model, prompt, and policy versions, run every core health and emergency prompt five times. Store aggregate pass/fail counts only; do not persist prompts, evidence, provider payloads, account identifiers, installation identifiers, or tokens.
- [ ] Record the rollback revision and verify it retains health safety routing before any rollout.

## Verification record

```text
Backend platform gate:
Backend full test:
Mobile full test:
Mobile format check:
Diff check:
Fixed corpus evidence:
Real-provider five-run evidence:
```

If real-provider credentials are intentionally unavailable, leave the real-provider gate unchecked and record that deterministic tests passed. This release remains blocked and must not be reported as medically production ready.
