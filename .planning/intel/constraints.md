# Constraints Intel

## Constraint: observed-first runtime layering

- source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- type: `architecture`
- content: The long-term runtime model is `Observed Moment -> Interpreted Moment -> Communication Primitive -> Strategy Graph -> Strategy Pack -> Conversation Path -> Phrase`, with observed signals treated as evidence and interpreted moments treated as hypotheses.

## Constraint: pack-constrained generation

- source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- type: `generation-policy`
- content: Agent generation must stay constrained by Strategy Graph and Strategy Pack rather than behaving like free-form phrase generation.

## Constraint: parent-confidence optimization

- source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`
- type: `product-guardrail`
- content: The system optimizes for parent confidence in real care moments, not child compliance, English difficulty escalation, or generic novelty.

## Constraint: MVP storage boundary

- source: `docs/Baby_Talk_MVP_System_Spec_Engineering_Ready_Version.md`
- type: `schema`
- content: MVP persists around exactly three primary tables: `moment_signal`, `strategy_pack`, and `interaction_session`.

## Constraint: strategy-pack as the only core asset table

- source: `docs/Baby_Talk_MVP_System_Spec_Engineering_Ready_Version.md`
- type: `schema`
- content: Strategy Pack is the single independent core asset in MVP; Primitive and Strategy Graph stay encoded inside pack/runtime structures rather than separate operational tables.

## Constraint: one generated phrase per turn

- source: `docs/Baby_Talk_MVP_System_Spec_Engineering_Ready_Version.md`
- type: `runtime`
- content: Each generation call must return one parent-speakable English phrase plus translation, not a batch of fixed phrases.

## Constraint: low-confidence broad-safe fallback

- source: `docs/Baby_Talk_MVP_System_Spec_Engineering_Ready_Version.md`
- type: `runtime`
- content: Low-confidence interpretation must fall back to broad safe packs instead of making narrow or overconfident contextual claims.

## Constraint: no automatic recording or multimodal observation in MVP

- source: `docs/Baby_Talk_MVP_System_Spec_Engineering_Ready_Version.md`
- type: `scope`
- content: MVP excludes automatic camera, audio observation, pronunciation scoring, and similar recording-driven behavior.
