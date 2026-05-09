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

## Deploy Configuration (configured by /setup-deploy)
- Platform: Kubernetes + Helm (Docker Desktop local cluster, namespace: babytalk)
- Production URL: N/A — local cluster only (port-forward: gateway=127.0.0.1:8090, admin-web=127.0.0.1:3000)
- Deploy workflow: manual helm upgrade (no auto-deploy on push)
- Project type: web app + API (Spring Boot backend + React admin-web)
- Merge method: squash

### Custom deploy hooks
- Pre-merge: none
- Deploy trigger: |
    helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -n babytalk --create-namespace -f deploy/helm/babytalk-infra/values-kind.yaml
    helm upgrade --install babytalk-app deploy/helm/babytalk-app -n babytalk -f deploy/helm/babytalk-app/values-kind.yaml -f deploy/helm/babytalk-app/values-kind-secrets.yaml
- Deploy status: |
    kubectl -n babytalk rollout status deployment/babytalk-app-gateway --timeout=120s
    kubectl -n babytalk rollout status deployment/babytalk-app-admin-api --timeout=120s
    kubectl -n babytalk rollout status deployment/babytalk-app-admin-web --timeout=120s
    kubectl -n babytalk rollout status deployment/babytalk-app-app-api --timeout=120s
- Health check: kubectl -n babytalk get pods

## QA Environment Configuration (configured by /setup-deploy)
- Platform: Kubernetes + Helm (Docker Desktop local cluster, namespace: babytalk-qa)
- Production URL: N/A — local cluster only (port-forward: gateway=127.0.0.1:8091, admin-web=127.0.0.1:3001)
- Deploy workflow: manual helm upgrade (no auto-deploy on push)
- Project type: web app + API (Spring Boot backend + React admin-web)
- Merge method: squash
- Persistence: Enabled (PVC with hostpath StorageClass)
- Storage: PostgreSQL 1Gi, Redis 256Mi, MinIO 5Gi

### QA Custom deploy hooks
- Pre-merge: none
- Deploy trigger: |
    helm upgrade --install babytalk-qa-infra deploy/helm/babytalk-infra -n babytalk-qa --create-namespace -f deploy/helm/babytalk-infra/values-kind-qa.yaml
    helm upgrade --install babytalk-qa-app deploy/helm/babytalk-app -n babytalk-qa -f deploy/helm/babytalk-app/values-kind-qa.yaml -f deploy/helm/babytalk-app/values-kind-qa-secrets.yaml
- Deploy status: |
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-gateway --timeout=120s
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-admin-api --timeout=120s
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-admin-web --timeout=120s
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-app-api --timeout=120s
- Health check: kubectl -n babytalk-qa get pods

<!-- superpowers-zh:begin (do not edit between these markers) -->
# Superpowers-ZH 中文增强版

本项目已安装 superpowers-zh 技能框架（20 个 skills）。

## 核心规则

1. **收到任务时，先检查是否有匹配的 skill** — 哪怕只有 1% 的可能性也要检查
2. **设计先于编码** — 收到功能需求时，先用 brainstorming skill 做需求分析
3. **测试先于实现** — 写代码前先写测试（TDD）
4. **验证先于完成** — 声称完成前必须运行验证命令

## 可用 Skills

Skills 位于 `.claude/skills/` 目录，每个 skill 有独立的 `SKILL.md` 文件。

- **brainstorming**: 在任何创造性工作之前必须使用此技能——创建功能、构建组件、添加功能或修改行为。在实现之前先探索用户意图、需求和设计。
- **chinese-code-review**: 中文代码审查规范——在保持专业严谨的同时，用符合国内团队文化的方式给出有效反馈
- **chinese-commit-conventions**: 中文 Git 提交规范 — 适配国内团队的 commit message 规范和 changelog 自动化
- **chinese-documentation**: 中文技术文档写作规范——排版、术语、结构一步到位，告别机翻味
- **chinese-git-workflow**: 适配国内 Git 平台和团队习惯的工作流规范——Gitee、Coding、极狐 GitLab、CNB 全覆盖
- **dispatching-parallel-agents**: 当面对 2 个以上可以独立进行、无共享状态或顺序依赖的任务时使用
- **executing-plans**: 当你有一份书面实现计划需要在单独的会话中执行，并设有审查检查点时使用
- **finishing-a-development-branch**: 当实现完成、所有测试通过、需要决定如何集成工作时使用——通过提供合并、PR 或清理等结构化选项来引导开发工作的收尾
- **mcp-builder**: MCP 服务器构建方法论 — 系统化构建生产级 MCP 工具，让 AI 助手连接外部能力
- **receiving-code-review**: 收到代码审查反馈后、实施建议之前使用，尤其当反馈不明确或技术上有疑问时——需要技术严谨性和验证，而非敷衍附和或盲目执行
- **requesting-code-review**: 完成任务、实现重要功能或合并前使用，用于验证工作成果是否符合要求
- **subagent-driven-development**: 当在当前会话中执行包含独立任务的实现计划时使用
- **systematic-debugging**: 遇到任何 bug、测试失败或异常行为时使用，在提出修复方案之前执行
- **test-driven-development**: 在实现任何功能或修复 bug 时使用，在编写实现代码之前
- **using-git-worktrees**: 当需要开始与当前工作区隔离的功能开发或执行实现计划之前使用——创建具有智能目录选择和安全验证的隔离 git 工作树
- **using-superpowers**: 在开始任何对话时使用——确立如何查找和使用技能，要求在任何响应（包括澄清性问题）之前调用 Skill 工具
- **verification-before-completion**: 在宣称工作完成、已修复或测试通过之前使用，在提交或创建 PR 之前——必须运行验证命令并确认输出后才能声称成功；始终用证据支撑断言
- **workflow-runner**: 在 Claude Code / OpenClaw / Cursor 中直接运行 agency-orchestrator YAML 工作流——无需 API key，使用当前会话的 LLM 作为执行引擎。当用户提供 .yaml 工作流文件或要求多角色协作完成任务时触发。
- **writing-plans**: 当你有规格说明或需求用于多步骤任务时使用，在动手写代码之前
- **writing-skills**: 当创建新技能、编辑现有技能或在部署前验证技能是否有效时使用

## 如何使用

当任务匹配某个 skill 时，使用 `Skill` 工具加载对应 skill 并严格遵循其流程。绝不要用 Read 工具读取 SKILL.md 文件。

如果你认为哪怕只有 1% 的可能性某个 skill 适用于你正在做的事情，你必须调用该 skill 检查。
<!-- superpowers-zh:end -->
