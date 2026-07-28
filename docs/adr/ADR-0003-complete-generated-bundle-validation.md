# ADR-0003: Complete Generated Bundle Validation

Date: 2026-07-28
Status: Accepted

## Context

Generated custom-scene content is a six-utterance care unit: one starter plus support for each canonical reaction. A starter-only provider response with fixed support text cannot express the selected care action or reaction, and validating only its starter lets unsafe support activate.

## Decision

Both Generator and Repair return one typed Complete Generated Bundle per provider operation. The typed schema requires exactly `starter`, `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`; missing, duplicate, or unknown reaction keys fail parsing.

Every utterance undergoes the same deterministic safety validation before registration or ACTIVE. Any terminal violation blocks the entire bundle. Repair receives and returns a complete bundle, then all six utterances are revalidated and judged.

The bundle owns shared scene metadata. Each utterance owns its phrase, pronunciation, TPR action, delivery guidance, difficulty, display order, role, canonical reaction, and provider provenance. Role, reaction, and provenance are separate dimensions: a starter has no reaction and every support has one canonical reaction; provenance cannot encode either.

Production code cannot derive a bundle from a starter, append fixed support text, replace a failed branch with generic support, or expose a starter-only wire response. Such behavior is limited to explicit fake and test fixtures.

## Consequences

Tests must assert one provider call, complete typed Generator and Repair responses, canonical scene/reaction-specific support, and terminal violations injected into every bundle position. Static verification prevents production fallback paths.
