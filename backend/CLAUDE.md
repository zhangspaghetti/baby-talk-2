# Backend Project CLAUDE.md

## 1. Spring Boot / Java Coding Standards
* **Java Version**: Java 17, Spring Boot 3.x.
* **Component Design**: 
  - Controllers: Keep controllers lean. Handle request mapping, parameter validation, and routing. Rely on services for business logic.
  - Services: House transaction limits, orchestration, and core business rules. Annotate with `@Transactional` where state writes occur.
  - Repositories/Mappers: Use MyBatis-Plus or Spring Data JPA. Define custom native query logic explicitly rather than embedding complex strings in code.
* **Security & Auth**: Follow robust authentication/authorization practices via Spring Security 6. Explicitly require appropriate permissions on all app-api and admin-api endpoints. Double-check all variables and inputs to guard against injection.
* **Naming Conventions**: 
  - Classes/Interfaces: `PascalCase`
  - Variables/Methods: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`
  - Package Folders: lowercase, single-word or dot-separated

## 2. Git Commit Standards
* **Format**: Follow traditional Conventional Commits: `<type>(<scope>): <subject>` (e.g., `feat(tts): integrate backend tts logic`).
* **Logical Units**: Each commit must be a minimally compileable, testable, and roll-backable unit.
* **Strict Checks**:
  - Run Maven builds and formatter prior to committing.
  - Do not commit code containing print-debugs, dummy test values, or commented lines.
  - Isolate DB migrations (Flyway) and schema alterations from general business feature code commits.

## 3. Expert Orchestration
* **Role-Based Pipeline**:
  - Planning (`@senior-project-manager`): Outlines steps and validation.
  - Development (`@backend-architect`): Conducts isolated modular updates, keeping gate security constraints compliant.
  - Debugging (`@investigate`): Employs structured logging and full root-cause investigation.
  - Review & Merge (`@code-reviewer` + human): Pre-reviews code for security, query optimization, and structural soundess.
* **Boundary Safeguards**: Do not touch dependencies or core shared definitions (e.g., `backend/common`) without clear authorization or broad-scope impact evaluation.

## 4. Superpowers Methodology
* **Systematic Debugging**: Use detailed stack traces and structured query logs to diagnose performance or security errors.
* **Validation Prior to Completion**: Run `mvn clean install` or target test classes, verifying they compile and pass with raw output proofs before claiming stability.
* **No Unbounded Retries**: If tests fail multiple times, halt, recheck schema compatibilities, audit database states, and resolve the root-cause.
