# Admin Web Project CLAUDE.md

## 1. React / Vite / Ant Design Coding Standards
* **Structure & UI**: Single page React application. Use Vite and Ant Design 5 (ProComponents). Incorporate customized themes/tokens in absolute design alignment with `DESIGN.md`. 
* **Component Organization**: Follow single responsibility. Extract complex UI blocks into local reusable functional components. Do not declare fresh top-level router routes unnecessarily; integrate into existing views unless explicitly planned.
* **Security & Fetching**: 
  - Manage authentication tokens securely via HttpOnly cookies (avoid raw storage of tokens in localStorage).
  - Use structured, caching fetchers (React Query/SWR) instead of direct `setInterval` or manual state-level polling.
* **Naming Conventions**: 
  - Components: `PascalCase` (e.g., `UserTable.tsx`)
  - Hooks: `camelCase`, prefixed with `use` (e.g., `useUserData.ts`)
  - Types/Interfaces: `PascalCase`, ending with `Props` or `Type`
  - Helpers/Constants: `UPPER_SNAKE_CASE`

## 2. Git Commit Standards
* **Format**: Follow traditional Conventional Commits: `<type>(<scope>): <subject>` (e.g., `fix(users): resolve filter resetting`).
* **Logical Units**: Keep commits focused and atomic. Every commit must pass formatting, build, and linter constraints.
* **Strict Checks**:
  - Run linting (`eslint`) and typechecking (`tsc`) before committing.
  - Do not commit unused imports, forgotten logs (`console.log`), or redundant lines.
  - Separately commit styling changes, state management adjustments, and dependency definitions.

## 3. Expert Orchestration
* **Role-Based Pipeline**:
  - Planning (`@product-manager` / `@senior-project-manager`): Maps out UI flows, behaviors, and designs before touching code.
  - Development (`@frontend-developer` / `@ui-designer`): Modifies UI components, strictly respects layout constraints and design specs.
  - Verification & QA (`@qa` / `@reality-checker`): Runs E2E Playwright tests to get reproducible test evidence.
* **Review Gates**: Do not bypass L1 AI Review or skip local validations before asking for human approval.

## 4. Superpowers Methodology
* **Systematic Debugging**: Leverage DevTools, structured frontend logs, and accurate locator diagnostics.
* **Validation Prior to Completion**: Execute `pnpm build`, typecheck, and local Playwright integration tests, ensuring flawless compilation and test passes with evidence.
* **No Unbounded Retries**: In case of flaky E2E tests, do not repeatedly click run. Inspect page elements, locators, transitions, and network state systematically.
