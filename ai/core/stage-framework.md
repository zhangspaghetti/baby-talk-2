# ASF Stage Framework

This project uses AI Software Factory governance version 2.7.2.

## Foundation Stages

| Stage | Goal | Commit Pattern |
| --- | --- | --- |
| Stage 0 | Establish governance directories, coding rules, and safety baseline | `chore: [Stage 0] init governance` |
| Stage 1 | Audit existing code and produce iteration plans | `docs: [Stage 1] audit & plan` |
| Stage 2 | Configure CI/CD, lint, and pre-commit style gates | `chore: [Stage 2] engineering setup` |

## Iteration Stages

| Stage | Goal | Commit Pattern |
| --- | --- | --- |
| Stage 3.0 | Design refinement and global planning | `docs: [Stage 3.0] design & plan` |
| Stage 3.1 | Implementation, debugging, verification, and review | `feat(module): [Stage 3.1] xxx` |
| Stage 4 | Verification and governance closeout | `test: [Stage 4] verification` |

## Stage 3.0 Gate

Stage 3.1 implementation must not begin until Stage 3.0 outputs are approved:

- Socratic design review, up to 15 questions.
- File-level global task list.
- Task dependency DAG.
- Unified interface contract where applicable.
- Global acceptance criteria and test strategy.
- Human approval recorded in `ai/context/`.
- Plan archived at `ai/context/stage-3.0-plan.md`.

## Stage Start Baseline

At the start of each stage, record the baseline commit:

```bash
mkdir -p ai/context && git rev-parse HEAD > ai/context/stage-start-commit.txt
```