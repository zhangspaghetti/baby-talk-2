# Phase 39 Context

## Milestone

M010 — 当前时刻对话模型重构与 v0.1 真实照护再验证

## Slice

S01 — Home / Practice / Onboarding 当前时刻模型收敛

## Why This Exists

An approved ingest of the following docs introduced a coherent redesign direction that overlaps, but does not yet supersede, the existing validated planning canon:

- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- `docs/Baby_Talk_MVP_System_Spec_Engineering_Ready_Version.md`
- `docs/Baby_Talk_MVP_Execution_Validation_Spec.md`
- `docs/design-spec/00_Asset_Gaps_Backlog.md`
- `docs/design-spec/06_Home_Screen.md`
- `docs/design-spec/07_Practice_Screen.md`
- `docs/design-spec/12_Onboarding_Screen.md`
- `docs/design-spec/README.md`

## Scope

This slice exists to settle the forward-looking interaction contract for:

- Home as a current-moment route launcher rather than a phrase-card page
- Practice as a one-phrase continuous loop with post-`我说了` optional baby feedback
- Onboarding as a one-real-turn proof of product promise rather than a fixed phrase-group tutorial

## Locked Boundaries

- Do not rewrite or erase the validated M001–M009 history in `.planning/PROJECT.md`, `.planning/ROADMAP.md`, or validated requirement proofs.
- Do not treat the ingest docs as automatic supersession of `R001`, `R002`, `R034`, or `R043`.
- Any implementation-phase plan must first state which existing contract is being replaced, preserved, or reinterpreted.

## Required Outputs

- A reconciled product-model decision for Home / Practice / Onboarding
- Explicit supersession map against current validated requirements
- A bounded implementation-ready phase plan for the chosen contract

## References

- `.planning/intel/SYNTHESIS.md`
- `.planning/INGEST-CONFLICTS.md`
- `.planning/intel/requirements.md`
- `.planning/intel/constraints.md`
