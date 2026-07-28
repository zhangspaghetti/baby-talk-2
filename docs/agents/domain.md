# Domain Docs

How engineering skills consume domain documentation while exploring this repo.

## Before exploring, read these

- `CONTEXT-MAP.md` at repo root. Read context `CONTEXT.md` files relevant to task:
  - `admin-web/CONTEXT.md`
  - `backend/CONTEXT.md`
  - `mobile/CONTEXT.md`
- `docs/adr/` for system-wide decisions touching work area.
- `<context>/docs/adr/` when context-scoped ADRs exist.

If files do not exist, proceed silently. Do not flag absence or create them upfront. `/domain-modeling` creates them lazily when terminology or decisions are resolved.

## File structure

```text
/
├── CONTEXT-MAP.md
├── docs/adr/                  ← system-wide decisions
├── admin-web/
│   ├── CONTEXT.md
│   └── docs/adr/              ← admin context decisions
├── backend/
│   ├── CONTEXT.md
│   └── docs/adr/              ← backend context decisions
└── mobile/
    ├── CONTEXT.md
    └── docs/adr/              ← mobile context decisions
```

## Use glossary vocabulary

Use terms defined by relevant `CONTEXT.md` in issue titles, refactor proposals, hypotheses, and test names. Do not replace explicitly defined terms with synonyms.

Missing concept signals either invented language or genuine glossary gap. Reconsider first; otherwise note it for `/domain-modeling`.

## Flag ADR conflicts

Surface conflicts with existing ADRs instead of silently overriding them:

> _Contradicts ADR-0007 — but worth reopening because…_
