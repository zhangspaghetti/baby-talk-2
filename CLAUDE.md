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
