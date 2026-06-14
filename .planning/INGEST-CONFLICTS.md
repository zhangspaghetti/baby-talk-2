## Conflict Detection Report

### BLOCKERS (0)

### WARNINGS (4)

[WARNING] Home entry model overlaps the existing validated Home interaction contract
  Found: `docs/design-spec/06_Home_Screen.md` defines Home as a four-route current-moment entry page with no Home phrase cards and Practice-owned first-phrase generation.
  Impact: Existing planning already validates Home as a shipped contextual-next-step surface tied to `R034` and the M009 S02 hierarchy centered on `HomeTodaySceneCard`.
  Source: `docs/design-spec/06_Home_Screen.md`; `.planning/REQUIREMENTS.md` (`R034`); `.planning/PROJECT.md` (M009 S02)
  → Decide whether this ingest should supersede the current Home interaction contract or be captured as a future redesign track.

[WARNING] Practice loop model introduces a new acceptance variant for the primary practice flow
  Found: `docs/design-spec/07_Practice_Screen.md` replaces fixed phrase-group/progress semantics with a one-phrase continuous loop where baby feedback appears only after `我说了`.
  Impact: Existing planning already marks the primary practice loop as validated under `R001`/`R043`; merging this doc without an explicit supersession rule risks mixing two product contracts for the same user flow.
  Source: `docs/design-spec/07_Practice_Screen.md`; `.planning/REQUIREMENTS.md` (`R001`, `R043`); `.planning/PROJECT.md`
  → Choose whether this doc updates the canonical Practice contract or should be attached as a future refactor/redesign requirement set.

[WARNING] Onboarding model overlaps the existing personalized onboarding requirement with a different completion shape
  Found: `docs/design-spec/12_Onboarding_Screen.md` allows onboarding completion after one real spoken phrase and removes fixed phrase-group progression.
  Impact: Existing planning already covers onboarding personalization under `R002`; merging this variant without explicit intent could blur which onboarding flow is canonical.
  Source: `docs/design-spec/12_Onboarding_Screen.md`; `.planning/REQUIREMENTS.md` (`R002`); `.planning/PROJECT.md`
  → Decide whether the new onboarding loop supersedes the current requirement interpretation or should be represented as a redesign milestone.

[WARNING] MVP v0.1 validation slice narrows scope below the current shipped/planned project footprint
  Found: `docs/Baby_Talk_MVP_Execution_Validation_Spec.md` explicitly cuts Discover, richer signal capture, and multiple advanced systems to validate a minimal real-care loop.
  Impact: The existing planning tree already records later milestones as complete and validated; ingesting the narrower MVP slice as-is could read like a rollback instead of a design-validation branch.
  Source: `docs/Baby_Talk_MVP_Execution_Validation_Spec.md`; `.planning/PROJECT.md`; `.planning/ROADMAP.md`
  → Decide whether to merge these items as historical validation context, as a new redesign/replatform phase, or not at all.

### INFO (2)

[INFO] Core product positioning aligns with the current project brief
  Note: The ingest docs reinforce the existing "实时双语育儿伴侣" framing and the rule that the product is not a classroom, flashcard library, or child-facing experience.
  Source: `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`; `docs/design-spec/README.md`; `.planning/PROJECT.md`

[INFO] Recording/scoring avoidance aligns with existing safety and failure-visibility requirements
  Note: The ingest docs consistently avoid microphone capture, pronunciation scoring, and opaque AI-language UI, which fits the current planning emphasis on safe mentor behavior and visible-but-gentle failure handling.
  Source: `docs/design-spec/07_Practice_Screen.md`; `docs/design-spec/12_Onboarding_Screen.md`; `.planning/REQUIREMENTS.md` (`R008`, `R011`)
