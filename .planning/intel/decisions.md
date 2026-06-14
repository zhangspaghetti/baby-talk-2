# Decisions Intel

No ADR-classified documents were present in this ingest set.

This staged ingest currently contributes synthesized requirements, constraints, and context only.

## DEC-2026-06-14-baby-talk-v1-activation-governor

- source: `$gsd-explore` session + `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- decision: Baby Talk v1 adopts `Activation Governor` as the pacing decision layer between Pack/Graph candidates and Runtime Agent response.
- rationale: The product risk is not lack of English content, but over-activating content until family English becomes a task, checklist, or performance ritual. The system should keep expert exploration open while conservatively controlling what enters daily family routine.
- boundaries:
  - Pack / Graph produce candidate content and strategy only.
  - Activation Governor controls `Activate`, not `Explore`.
  - Runtime Agent applies an existing activation decision; it must not self-evaluate activation policy.
  - Garden Memory presents state and collects parent confirmation; it is not the decision core.
- default policy: conservative activation, open exploration. v1 default active capacity is 3 micro-rituals; mature-family upper bound is internal and must not be exposed as a user goal.
- success metric: parent-confirmed micro-ritual transfer into real routines, not generated content volume, streaks, or checklist completion.
