# AI Directory Migration Plan

Status: Wave 0 scaffold is committed. Wave 1 and Wave 2 were approved by the human owner and executed with `git mv`. Wave 3 and Wave 4 remain pending.

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
- `reports/`
- `reviews/`
- `tasks/`

Migrated evidence namespace:

- `context/refactor/`

Observed issues:

- Stable rules, architecture evidence, task records, and verification reports are mixed by historical topic rather than lifecycle role.
- `context/` is already the right place for plans and decisions, and the old `completed-decisions/` namespace has been aligned to `resolved-decisions/`.
- Refactor evidence now lives under `ai/context/refactor/` as formal versioned evidence.
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

Completed:

- Add `ai/GOVERNANCE_VERSION`.
- Add project-local core governance files under `ai/core/`.
- Add Flutter governance files under `ai/tech-stacks/flutter/`.
- Add integration and operations readmes.
- Add `ai/runtime/.gitignore`.

### Wave 1: Decision Directory Alignment

Approved and completed:

- Moved `ai/context/completed-decisions/` to `ai/context/resolved-decisions/`.
- Updated references from `completed-decisions` to `resolved-decisions`.

### Wave 2: Formal Evidence Consolidation

Approved and completed:

- Moved `ai/refactor/**` to `ai/context/refactor/**`.
- Updated tracked documentation references from `ai/refactor/...` to `ai/context/refactor/...`.
- Kept the moved tree versioned as formal evidence.

The moved namespace is now the canonical location for refactor task records, audit reports, migration plans, and verification reports.

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

1. Should empty legacy directories be deleted after `.gitkeep` verification?
2. Should architecture documents remain under `ai/architecture/`, or move to `ai/context/architecture/` after reference checks?

## Verification Plan

Before any remaining move or cleanup commit:

- Run a path-reference search for every moved directory.
- Use `git mv` for tracked files.
- Keep migration commits documentation-only.
- Run `git status --short` and `git diff --check`.
- Do not edit Flutter product code in the same commit.