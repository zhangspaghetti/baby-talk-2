# Need Confirmation: R1 Mentor Consent Gate

ID: HDR-R1-003  
Level: Red  
Stage: R1  
Created: 2026-05-18  
Status: confirmed

## Current Task

Prepare R2 security/privacy planning for AI-backed mentor chat.

## Problem Description

R1 security audit found that mentor chat sends free-form prompt/context data through the mentor API path. For a child-focused product, outbound AI calls need an explicit consent and account policy before implementation refactors continue.

## Decision Level

Red: child privacy and AI data handling decision.

## Existing Information

- Mentor chat can include user free text, context summary, and installation identifier.
- Factory config requires COPPA/GDPR-style privacy governance.
- Product memory also includes PIPL considerations for child profile data.

## Options

1. Require parent login and accepted consent before any mentor chat network call; unauthenticated or unconsented users receive local-only suggestions.
2. Allow limited unauthenticated mentor chat with minimized payload and server-side safeguards.

## Recommendation

Choose option 1. It is the safer default for child privacy and easier to test fail-closed.

## Risk Assessment

| Option | Risk |
|---|---|
| Login + consent required | May reduce unauthenticated demo functionality; requires clear UX state |
| Limited unauthenticated chat | Higher privacy/compliance risk and harder audit trail |

## Required Confirmation

Confirmed on 2026-05-18: mentor/AI network calls require parent login and accepted consent. Unauthenticated or unconsented users must receive local-only behavior and must not send mentor network requests.