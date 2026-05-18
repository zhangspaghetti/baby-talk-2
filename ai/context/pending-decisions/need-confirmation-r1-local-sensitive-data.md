# Need Confirmation: R1 Local Sensitive Data Policy

ID: HDR-R1-004  
Level: Red  
Stage: R1  
Created: 2026-05-18  
Status: confirmed

## Current Task

Prepare R2 local data protection planning.

## Problem Description

R1 security audit found child profile, household context, practice events, mentor facts, and installation ID storage paths that need explicit classification and deletion/encryption rules before implementation refactors.

## Decision Level

Red: security, privacy, and data lifecycle decision.

## Existing Information

- Onboarding data includes child display name and age/birth information.
- Household data includes baby, continuity, and garden summaries.
- Practice and mentor local stores can include behavior/fact history.
- Installation ID is a stable identifier.

## Options

1. Classify these as sensitive child/household data; require encryption or secure storage where applicable, backup exclusion where possible, and explicit delete-on-logout/consent-withdrawal/account-delete behavior.
2. Keep current local storage behavior and document it as acceptable for MVP.

## Recommendation

Choose option 1. It aligns with child privacy expectations and gives R3 a safe target for storage refactors.

## Risk Assessment

| Option | Risk |
|---|---|
| Sensitive classification | Requires migration plan and regression tests for local data lifecycle |
| Current behavior acceptable | Higher privacy exposure and weak long-term compliance story |

## Required Confirmation

Confirmed on 2026-05-18: child, household, practice, mentor, and installation data are sensitive local data. R2/R3 must plan encryption or secure storage where applicable, backup exclusion where possible, and explicit deletion on logout, consent withdrawal, and account deletion.