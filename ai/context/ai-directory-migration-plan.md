# AI Directory Migration Plan

Status: Draft for human approval. No legacy files have been moved by this plan.

## Goal

Migrate the project-local `ai/` directory toward the ASF 2.7.2 layout without creating a second source of truth or losing audit evidence.

## Current Layout Audit

Current top-level directories:

- `architecture/`
- `context/`
- `design-system/`
- `enforcement/`
- `engineering/`
- `governance/`
- `product/`
- `refactor/`
- `reports/`
- `reviews/`
- `tasks/`

Observed issues:

- Stable rules, architecture evidence, task records, and verification reports are mixed by historical topic rather than lifecycle role.
- `context/` is already the right place for plans and decisions, but it uses `completed-decisions/` while ASF expects `resolved-decisions/`.
- `refactor/` contains formal evidence that should remain versioned, but it is large enough that moving it in one step would be hard to review.
- Empty legacy buckets such as `design-system/`, `enforcement/`, `engineering/`, `product/`, `reports/`, `reviews/`, and `tasks/` need explicit approval before removal.

## Target Layout

The recommended target is:

```text
ai/
├── GOVERNANCE_VERSION
├── core/
├── tech-stacks/
│   └── flutter/
├── integrations/
├── operations/
├── context/
└── runtime/
```

`context/` remains the home for formal evidence. `runtime/` is ignored short-lived noise. Static governance rules live in `core/`, `tech-stacks/`, `integrations/`, and `operations/`.

## Migration Waves

### Wave 0: Non-Destructive Scaffold

Already safe to do:

- Add `ai/GOVERNANCE_VERSION`.
- Add project-local core governance files under `ai/core/`.
- Add Flutter governance files under `ai/tech-stacks/flutter/`.
- Add integration and operations readmes.
- Add `ai/runtime/.gitignore`.

### Wave 1: Decision Directory Alignment

Requires human approval because it moves existing files:

- Move `ai/context/completed-decisions/` to `ai/context/resolved-decisions/`.
- Update references from `completed-decisions` to `resolved-decisions`.

### Wave 2: Formal Evidence Consolidation

Requires human approval and reference checks:

- Keep `ai/refactor/**` versioned as formal evidence.
- Either leave it as a documented legacy evidence namespace, or move it to `ai/context/refactor/**`.
- If moved, update all docs that reference `ai/refactor/...` paths.

Recommended first pass: leave `ai/refactor/**` in place and document it as legacy formal evidence until the next milestone closes.

### Wave 3: Empty Legacy Bucket Cleanup

Requires human approval before deletion:

- Remove empty top-level buckets only after checking they contain no non-placeholder files.
- Candidate directories: `design-system/`, `enforcement/`, `engineering/`, `product/`, `reports/`, `reviews/`, `tasks/`.

### Wave 4: Architecture Document Placement

Requires document-by-document review:

- Keep architectural evidence in `ai/context/architecture/`, or keep `ai/architecture/` as a documented legacy evidence namespace.
- Convert only stable process rules into `ai/operations/` or `ai/tech-stacks/flutter/`.
- Do not mechanically move all architecture docs into static rules.

## Approval Questions

1. Should `ai/refactor/**` remain as a legacy formal evidence namespace for this milestone, or move to `ai/context/refactor/**` now?
2. Should empty legacy directories be deleted after `.gitkeep` verification?
3. Should `completed-decisions/` be renamed to `resolved-decisions/` now?

## Verification Plan

Before any move commit:

- Run a path-reference search for every moved directory.
- Use `git mv` for tracked files.
- Keep migration commits documentation-only.
- Run `git status --short` and `git diff --check`.
- Do not edit Flutter product code in the same commit.