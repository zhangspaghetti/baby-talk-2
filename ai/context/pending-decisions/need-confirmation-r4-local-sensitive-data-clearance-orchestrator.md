# Need Confirmation: R4 Local Sensitive Data Clearance Orchestrator

ID: HDR-R4-001  
Level: Red  
Stage: R4  
Created: 2026-05-19  
Status: pending

## Current Task

Confirm whether to implement and later wire a Flutter local sensitive data clearance orchestrator for account/session, onboarding, household, practice, mentor, and installation ID stores.

## Problem Description

REFACTOR-019 closed the missing installation ID delete primitive, so all six sensitive local surfaces now have explicit primitive-level deletion support. The app still lacks one orchestrator that attempts all approved deletions, captures partial failures, and produces audit evidence before any account deletion, consent withdrawal, or device-erasure flow can claim local clearance.

## Decision Level

Red: destructive local data lifecycle, child-sensitive data, privacy evidence, and user-visible account lifecycle behavior.

## Existing Information

- `ai/architecture/local-sensitive-data-lifecycle.md` classifies account, onboarding, household, practice, mentor, and installation ID data as sensitive.
- `ai/architecture/local-sensitive-data-clearance-orchestrator-interface.md` proposes a report-producing orchestrator interface.
- REFACTOR-019 proves `InstallationIdService.deleteIfExists()` exists, but explicitly does not wire it into destructive flows.
- REFACTOR-018 and R4 verification artifacts keep production readiness and deletion blocked pending explicit human confirmation.

## Options

1. Approve implementation of the orchestrator interface as a test-first, behavior-preserving service with no production flow wiring.
2. Approve wiring the orchestrator into one destructive production trigger after separate UX copy, retry behavior, support flow, and target-platform tests are approved.
3. Defer the orchestrator and continue relying on scattered primitive calls.

## Recommendation

Choose option 1 only. Implement the orchestrator behind tests and report-only verification first, but do not wire logout, consent withdrawal, account deletion, onboarding reset, or device erasure until a separate red-level approval explicitly selects the trigger, UX confirmation text, retry behavior, and verification gate.

## Risk Assessment

| Option | Risk |
|---|---|
| Implement orchestrator only | Adds interface and tests without changing runtime behavior; lowest path to auditability |
| Wire destructive flow now | High risk of irreversible local child/practice data deletion, partial failures, and weak user recovery |
| Defer orchestrator | Continues fragmented deletion evidence and makes future privacy claims hard to prove |

## Required Confirmation

Human must explicitly confirm the selected implementation scope before any Flutter production code is changed. A separate confirmation is required before any destructive user-visible flow calls the orchestrator.