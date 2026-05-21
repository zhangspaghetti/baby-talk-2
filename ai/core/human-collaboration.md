# Human Collaboration Gates

Stop and request human confirmation when any of these apply:

- Deleting existing production code.
- Changing public API signatures.
- Adding third-party dependencies.
- Changing database schema.
- Making an architecture decision that is unclear against project conventions.

Recommended confirmation points:

- Product requirements are ambiguous.
- Multiple implementation options have meaningful tradeoffs.
- A refactor may affect a core business flow.
- User data, privacy, security, or destructive data handling is involved.
- A new environment variable is needed.

Decision records live in:

- Pending decisions: `ai/context/pending-decisions/`
- Resolved decisions: `ai/context/resolved-decisions/`
- Archived decisions: `ai/context/archive/`

Use this shape for decision records:

```text
category: <category>
priority: red|yellow|low
task: <current task>
problem: <specific decision>
options: <numbered options>
recommendation: <recommended option and reason>
risk: <risk summary>
confirmation_needed: <yes/no>
```