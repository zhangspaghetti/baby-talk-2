# Flutter State Management Rules

## State Layers

- Global app state belongs in Riverpod providers or existing app-level notifiers.
- Page async state should use `AsyncValue` when introducing new Riverpod surfaces.
- Local ephemeral UI state may stay in `StatefulWidget`, `setState`, or `ValueNotifier`.
- Do not store business logic in widgets when a repository, notifier, or use-case boundary already exists.

## Riverpod Rules

- Handle loading, error, and data states explicitly.
- Prefer `autoDispose` when a provider is not expected to outlive its screen.
- Avoid expanding feature-to-feature imports; use contracts or app-level composition seams.

## Current Project Caution

This codebase still contains legacy `ChangeNotifier` flows. Migration must be incremental: wrap or adapt one visible slice at a time, then verify behavior before changing wider state ownership.