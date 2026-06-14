# Phase 40 Context

## Milestone

M010 — 当前时刻对话模型重构与 v0.1 真实照护再验证

## Slice

S02 — MVP v0.1 真实照护验证与埋点闭环

## Scope

This slice converts the ingested MVP validation spec into a concrete revalidation track that can answer:

- Do parents open the app in real care moments?
- Do they speak the first phrase?
- Do they continue at least one more turn?
- Is latency low enough for in-the-moment use?

## Required Signals

- Session start by care window
- First phrase exposure
- `我说了` conversion
- Second-phrase exposure
- Optional baby feedback participation
- Session end / abandon
- 7-day repeat usage

## Constraints

- Use explicit kill criteria, not taste or optimism
- Keep validation tied to the low-friction current-moment loop
- Avoid introducing dashboard or growth-surface scope before the loop is proven

## References

- `docs/Baby_Talk_MVP_Execution_Validation_Spec.md`
- `.planning/intel/requirements.md`
- `.planning/intel/constraints.md`
