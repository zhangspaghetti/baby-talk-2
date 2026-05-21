# Flutter UI Guidelines

## Responsive Layout

- Use constraints from `LayoutBuilder` for layout decisions.
- Breakpoints: compact below 600dp, medium from 600dp to 840dp, expanded above 840dp.
- Do not branch on device type.
- Prefer flexible layouts with `Flex`, `Expanded`, and explicit constraints.

## Material 3 And Theme

- Use project `ThemeData`, `BabyTalkColors`, and `AppLayoutConstants` as token sources.
- Keep light and dark theme support intact.
- Prefer Material 3 components for navigation, cards, buttons, and feedback.

## Interaction

- Interactive targets must be at least 48dp by 48dp.
- Buttons and custom controls need visible pressed/focus feedback.
- Loading, empty, error, and data states must be explicit for migrated surfaces.

## Accessibility

- Interactive and non-standard UI elements need meaningful `Semantics` labels.
- Text contrast target is at least 4.5:1 for body text.
- Migrated surfaces must remain usable with TalkBack and VoiceOver.