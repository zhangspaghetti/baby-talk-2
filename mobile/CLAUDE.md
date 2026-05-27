# Mobile Project CLAUDE.md

## 1. Flutter / Riverpod Coding Standards
* **State Management**: Use Riverpod (v2) with code generation (`@riverpod`). Keep Notifiers side-effect free in initialization. No multiple notifier interactions inside a single state update; use separate events.
* **Architecture**: Follow layered clean architecture: UI/Presentation (screens, widgets), Business Logic (notifiers/controllers), and Data (repositories, domain models).
* **Routing**: Use `go_router` for route definition and navigation. Define routes statically or dynamically in routing configs.
* **Naming Conventions**: 
  - Classes/Widgets: `PascalCase`
  - Variables/Functions: `camelCase`
  - Files: `snake_case.dart`
  - Folders: `snake_case`
* **Widget Constraints**: Prefer composition over inheritance. Widgets should be granular and small. Extract complex subtrees into distinct functional widgets. Keep lifecycle overrides minimal and organized.

## 2. Git Commit Standards
* **Format**: Follow traditional Conventional Commits: `<type>(<scope>): <subject>` (e.g., `feat(onboarding): add option scroll animation`).
* **Logical Units**: Keep commits small, self-contained, and completely testable. One commit = one rollbackable logic subunit.
* **Strict Checks**:
  - Run typecheck and formatting prior to commit.
  - Do not commit code containing debugging prints, non-functional commented blocks, or unhandled exceptions.
  - Strictly separate feature implementations, refactors, dependencies, and documentation updates into separate commits.

## 3. Expert Orchestration
* **Role-Based Pipeline**: Tasks are planned and verified against explicit acceptance criteria.
  - Planning (`@senior-project-manager`): Outputs plan in `ai/context/`.
  - Development (`@mobile-app-developer`): Done in isolated worktree branches, code is self-tested.
  - Debugging (`@investigate`): Root-cause driven, four-phase analysis, no trial-and-error fixes.
  - Verification (`@reality-checker`): Generates evidence check in `verification-[task-id].md`.
* **Resource Separation**: Every distinct task runs in isolated environments (or dedicated git branches) to guarantee that cross-dependencies are minimized and the main branch is protected.

## 4. Superpowers Methodology
* **Systematic Debugging**: Prioritize understanding the root cause over trial-and-error changes.
* **Validation Prior to Completion**: Run `flutter test` or relevant test suites and verify success with actual evidence (e.g. terminal execution stats or screenshot confirmations) before declaring completion.
* **No Unbounded Retries**: If tests fail multiple times, halt and re-analyze the root cause using the structured four-phase debugging protocol.
