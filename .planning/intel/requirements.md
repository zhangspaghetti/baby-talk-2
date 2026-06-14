# Requirements Intel

## REQ-home-current-moment-entry

- source: `docs/design-spec/06_Home_Screen.md`
- description: Home must act as the current-moment conversation entry page rather than a phrase-card or checklist surface.
- acceptance_criteria:
  - Home shows exactly four visible direct care-context routes on first render.
  - Home never renders English phrase cards or in-place pronunciation controls.
  - Practice owns first-phrase generation after navigation.

## REQ-home-resume-and-context-helpers

- source: `docs/design-spec/06_Home_Screen.md`
- description: Home must expose a continue affordance for a recent open conversation plus low-friction signal and custom-situation entry paths.
- acceptance_criteria:
  - A continue entry appears only for an open conversation updated within 30 minutes.
  - Baby signal entry opens a lightweight pre-start signal sheet.
  - Custom situation entry accepts a short Chinese description and hands off to Practice.

## REQ-practice-one-phrase-turn-loop

- source: `docs/design-spec/07_Practice_Screen.md`
- description: Practice must run as a repeating one-phrase conversational loop rather than a fixed phrase set or progress-driven exercise.
- acceptance_criteria:
  - Only one current English phrase is shown as the primary surface per turn.
  - The user can continue indefinitely instead of completing a fixed count.
  - The end action is a gentle exit, not a task-completion state.

## REQ-practice-post-spoken-feedback

- source: `docs/design-spec/07_Practice_Screen.md`
- description: Baby feedback must appear only after the parent confirms the phrase was spoken, and it must remain optional.
- acceptance_criteria:
  - `我说了` is the only primary CTA in the ready state.
  - Baby signal options appear only after `我说了`.
  - If no signal is chosen, the flow auto-continues after 4 seconds using an unspecified signal.

## REQ-practice-no-recording-or-scoring

- source: `docs/design-spec/07_Practice_Screen.md`
- description: Practice must support standard pronunciation playback without implying recording, scoring, or correction.
- acceptance_criteria:
  - Standard pronunciation uses speaker/play semantics only.
  - No microphone, waveform, dictation, or pronunciation scoring UI appears.
  - Baby speech follow-up is captured via lightweight text input only.

## REQ-onboarding-contextual-first-turn

- source: `docs/design-spec/12_Onboarding_Screen.md`
- description: Onboarding must prove the product promise through a real first-turn contextual conversation rather than a fixed phrase-group tutorial.
- acceptance_criteria:
  - The first screen shows four situation routes and no English phrase list.
  - The first phrase is requested only after a route is chosen.
  - The second phrase must be framed as context-aware continuation, not a prewritten sequence.

## REQ-onboarding-low-pressure-completion

- source: `docs/design-spec/12_Onboarding_Screen.md`
- description: Onboarding must complete after a real spoken moment without forcing profile completion or a fixed number of turns.
- acceptance_criteria:
  - One spoken phrase is sufficient for onboarding completion.
  - Baby nickname and age remain optional.
  - The user can defer and resume without guilt language.

## REQ-v01-real-care-validation-loop

- source: `docs/Baby_Talk_MVP_Execution_Validation_Spec.md`
- description: The initial MVP must be judged by whether parents can open the app in a real care moment, speak one phrase, and continue naturally.
- acceptance_criteria:
  - Validation tracks start-to-first-phrase, phrase-to-spoken, and continuation behavior in real care windows.
  - The loop remains usable with minimal required feedback.
  - Iteration decisions use explicit kill criteria rather than subjective preference.

## REQ-v01-instrumented-session-behavior

- source: `docs/Baby_Talk_MVP_Execution_Validation_Spec.md`
- description: The v0.1 product slice must emit enough session telemetry to evaluate startup, continuation, abandonment, and repeat-use hypotheses.
- acceptance_criteria:
  - Session start, phrase exposure, spoken confirmation, optional reaction, next-phrase request, and session end/abandon are all observable.
  - The system can compute second-phrase exposure, average spoken turns, and repeat-session rates from the captured data.
  - Real-user validation can be reviewed without a full analytics dashboard.

## REQ-v1-activation-governor

- source: `$gsd-explore` session, 2026-06-14
- description: Baby Talk v1 must place an Activation Governor between Pack/Graph candidates and Runtime Agent responses to decide whether candidate content may enter family daily routine.
- acceptance_criteria:
  - Runtime uses `candidatePack` plus an `activationDecision`, never an already-active pack chosen by Runtime itself.
  - New micro-ritual activation is gated by active capacity, Garden Memory state, parent-confirmed readiness, and taskification risk.
  - Explore content remains accessible even when activation is deferred.

## REQ-v1-garden-memory

- source: `$gsd-explore` session, 2026-06-14
- description: Garden Memory must be a parent-confirmed memory layer for family English micro-ritual transfer, not a completion tracker or scoring system.
- acceptance_criteria:
  - Garden state can represent candidate, active, familiar, resting, expandable, and belongs-to-family.
  - State changes rely on low-pressure parent confirmation; telemetry can only provide weak signals.
  - Garden may display pacing outcomes but must not own activation policy.

## REQ-v1-parent-confirmed-transfer-metrics

- source: `$gsd-explore` session, 2026-06-14
- description: v1 validation must measure whether micro-rituals transfer into real routines without pressure, rather than counting generated phrases, checklist completion, streaks, or usage volume.
- acceptance_criteria:
  - Metrics include first active micro-ritual spoken without pressure.
  - Metrics include parent-confirmed familiar and belongs-to-family state transitions.
  - Metrics can identify which Pack candidates produce transfer without rewarding content quantity.
