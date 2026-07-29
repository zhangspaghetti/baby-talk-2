# ADR-0003: Complete Generated Bundle Validation

Date: 2026-07-28
Status: Accepted

## Context

Generated custom-scene content is a six-utterance care unit: one starter plus support for each canonical reaction. A starter-only provider response with fixed support text cannot express the selected care action or reaction, and validating only its starter lets unsafe support activate.

## Decision

Each generation attempt and each repair attempt consumes exactly one typed provider response containing a Complete Generated Bundle. The orchestration may retain its explicitly bounded number of repair attempts. The typed schema requires exactly `starter`, `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`; missing, duplicate, or unknown reaction keys fail parsing.

Every utterance undergoes the same deterministic safety validation before registration or ACTIVE. The approved `GeneratedOutputViolationCode` classification is:

- Terminal: `OUTPUT_PII`, `OUTPUT_BIDI_CONTROL`, `OUTPUT_ADULT_VIOLENT`, `OUTPUT_DANGEROUS_MEDICAL`, `UNTRUSTED_METADATA`, `DATABASE_OVERFLOW`, and `INVALID_ENUM`.
- Repairable: `MISSING_TPR_ACTION`, `MISSING_DELIVERY_GUIDANCE`, `FIELD_ROLE_MISMATCH`, `META_INSTRUCTION`, `COURSE_OR_SCORING_FRAMING`, and `MARKDOWN_OR_TEMPLATE`.

A terminal violation rejects the entire bundle without Repair, Judge, persistence, registration, or ACTIVE. A repairable violation requires one complete-bundle Repair attempt; all six utterances are then revalidated and the complete bundle is judged. Only an application-computed effective PASS with valid activation provenance permits registration and ACTIVE. Any change to this classification requires explicit policy/ADR revision, not a test-name change.

The bundle owns shared scene metadata. Each utterance owns its phrase, pronunciation, TPR action, delivery guidance, difficulty, display order, role, canonical reaction, and provider provenance. Role, reaction, and provenance are separate dimensions: a starter has no reaction and every support has one canonical reaction; provenance cannot encode either.

Production code cannot derive a bundle from a starter, append fixed support text, replace a failed branch with generic support, or expose a starter-only wire response. Such behavior is limited to explicit fake and test fixtures.

## Consequences

Tests must assert one provider call per generation/repair attempt, complete typed Generator and Repair responses, canonical scene/reaction-specific support, each approved terminal and repairable classification injected into every bundle position, terminal rejection, repairable full-bundle repair, application-computed Judge PASS before activation, and violations injected into every bundle position. Static verification prevents production fallback paths.
