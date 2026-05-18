# Need Confirmation: R1 Mobile Auth Strategy

ID: HDR-R1-002  
Level: Red  
Stage: R1  
Created: 2026-05-18  
Status: confirmed

## Current Task

Prepare R2 security and architecture planning for protected mobile API calls.

## Problem Description

R1 security audit found that access token handling and request header injection are not clearly unified. The app must choose one canonical mobile authentication source before refactoring account, household, mentor, dynamic practice, or share flows.

## Decision Level

Red: security, privacy, and public API behavior decision.

## Existing Information

- Several API services accept or operate near access-token state.
- Audit did not find a complete and consistent `Authorization: Bearer ...` injection strategy.
- Mixed Cookie/JWT behavior can cause session confusion and unreliable tests.

## Options

1. Use Bearer JWT as the canonical mobile auth source; inject it through one authenticated client/interceptor and test every protected API.
2. Use Cookie/session as the canonical mobile auth source; remove unused JWT assumptions from mobile code.

## Recommendation

Choose option 1. It matches mobile API expectations and makes auth behavior explicit in tests.

## Risk Assessment

| Option | Risk |
|---|---|
| Bearer JWT | Requires coordinated tests and possible backend contract checks |
| Cookie/session | Mobile session state may remain implicit and harder to secure/debug |

## Required Confirmation

Confirmed on 2026-05-18: protected mobile API calls must use explicit Bearer JWT auth through one authenticated client/interceptor.