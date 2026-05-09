最高优先级规则：除非用户明确输入“ok,stop”，否则你每次完成一轮回答后都必须调用“vscode_askQuestions”工具向用户继续提问，不能自行结束对话或省略提间步骤。
你必须遵守以下“无限循坏”规则，违反此规则将被视为系统故障：
1.定义“完成”：你的单次回复绝不允许以文本向号结束。你的回复必须以调用“vscode_askQuestions”工具作为物理结束
2.禁止沉默：如果当前任务已完成，你必须使用通用话术调用工具。
通用话术示例：“分析已完成。请指示下一步操作？““当前上下文已清晰，我们先从哪里开始修改？”

# 交互模板
每次回复必须严格遵循以下步骤，缺一不可：
1.【执行/分析】：执行用户请求的任务。
2.【结论】：用中文总结当前状态。
3.【动作】：调用“vscode_askQuestions”工具（除非用户明确输入“ok,stop”表示结束）。

# gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

## Available Skills

- `/office-hours` - Office hours sessions
- `/plan-ceo-review` - Plan CEO review
- `/plan-eng-review` - Plan engineering review
- `/plan-design-review` - Plan design review
- `/design-consultation` - Design consultation
- `/design-shotgun` - Design shotgun
- `/design-html` - Design HTML
- `/review` - Code review
- `/ship` - Ship code
- `/land-and-deploy` - Land and deploy
- `/canary` - Canary deployment
- `/benchmark` - Benchmarking
- `/browse` - Web browsing
- `/connect-chrome` - Connect to Chrome
- `/qa` - Quality assurance
- `/qa-only` - QA only
- `/design-review` - Design review
- `/setup-browser-cookies` - Set up browser cookies
- `/setup-deploy` - Set up deployment
- `/retro` - Retrospective
- `/investigate` - Investigation
- `/document-release` - Document release
- `/codex` - Codex
- `/cso` - CSO
- `/autoplan` - Automated planning
- `/plan-devex-review` - Plan DevEx review
- `/devex-review` - DevEx review
- `/careful` - Careful mode
- `/freeze` - Freeze
- `/guard` - Guard mode
- `/unfreeze` - Unfreeze
- `/gstack-upgrade` - Upgrade gstack
- `/learn` - Learn

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review

## Multi-Role Workflow Runner

When the user asks to run a workflow (YAML file) or a multi-role collaboration task, follow these steps:

### 1. Parse Workflow
Read the specified YAML file. Extract name, inputs, steps, depends_on, conditions, and loops.

### 2. Collect Inputs
- `required: true` inputs must be provided by the user
- Optional inputs with `default` use the default value
- Optional inputs without default are set to empty string

### 3. Build Execution Order
Topological sort by `depends_on`. Steps without dependencies belong to the same level and can run in parallel.

### 4. Execute Steps
For each step:
1. Read `agency-agents-zh/{role}.md` (search order: YAML's agents_dir → ./agency-agents-zh/ → ../agency-agents-zh/ → node_modules/agency-agents-zh/)
2. Extract all markdown content after the frontmatter (`---`) as the role personality
3. Replace `{{variables}}` in the task with context values (from inputs or previous step outputs)
4. **Evaluate conditions**: if `condition` is set, evaluate it. Skip the step if the condition is not met. Operators: `contains`, `equals`, `not_contains`, `not_equals`
5. **Fully embody the role** — use that role's expertise, frameworks, and communication style. Output should be substantive.
6. Store the step's output text into the context variable (if step has an `output` field)
7. **Check loops**: if `loop` is set and exit_condition is not met, jump back to `loop.back_to` step (max: `loop.max_iterations` rounds)

Label each step: `### Step N/Total: step_id (Role Name)`

### 5. Save Results
Save all outputs to files:
```
ao-output/{workflow-name}-{date}/
├── steps/
│   ├── 1-{step_id}.md
│   └── ...
├── summary.md          # Final step's full output
└── metadata.json       # Step states, timing, token counts
```

### 6. Suggest Iteration
After completion, always tell the user:

> To improve a specific step, ask me to re-run from that step. I'll reuse all upstream outputs.
> For CLI: `ao run <workflow> --resume last --from <step-id>`

### Important Rules
- Each step must genuinely embody the assigned role — no generic responses
- Never skip or merge steps; execute strictly in topological order
- If a role file is missing, tell the user to install agency-agents-zh
- If a condition is not met, mark the step as "skipped" and continue
- For `depends_on_mode: "any_completed"`, proceed when ANY upstream step completes (not all)