# Phase 41 D.4.5 Device UAT Completion Design

**Date:** 2026-06-22
**Status:** Approved for implementation planning
**Primary device:** Android, `427×952dp` logical viewport, `1280×2856px` physical resolution
**Visual authority:** `.planning/phases/41-mobile-v2-runnable-vertical-slice/assets/prototypes/phase41-d4-5-interaction-engine.png`

## Purpose

Phase 41 is code-green but not human-verification complete. This design closes the remaining device UAT gaps without turning the acceptance harness or bundled audio into a permanent product architecture decision.

The accepted outcome is a real, device-verifiable flow:

```text
READY
→ select “还不想穿”
→ SUBMITTING
→ result not confirmed
→ retry the exact event
→ engine reconciliation
→ REVISED
```

Throughout that flow:

- the parent sees one current speakable utterance
- the current utterance's English, Chinese support, and audio identity change together
- the retry path uses the real API, DTO, mapper, repository, engine, snapshot, notifier, and UI
- internal engine and transport language never enters product UI or TalkBack

## Current Failures

The current Android runner proves that the app launches and that TalkBack can select a reaction, but it does not satisfy D.4.5:

1. The layout is structurally different from the approved prototype.
2. `normalizedContext.eventSummary` exposes internal English such as `the shared routine is currently difficult to enter`.
3. The fixture marks audio unavailable, and `BabyTalkApp.onListen` is an empty callback.
4. The product path cannot deliberately exercise delayed completion or a post-commit lost response.
5. Unknown-outcome retry is covered by automated tests but cannot be reproduced reliably on a device.

This is a structural and boundary problem, not a color-and-spacing polish task.

## Scope

This design includes:

- D.4.5-aligned Ritual Room geometry
- a presentation-safe `ProductSnapshot.activeUtterance`
- two Phase 41 bundled acceptance audio assets
- an `AudioPlaybackPort` and local bundled-audio adapter
- a debug/profile-only Interaction API decorator for UAT
- device-reproducible delay and lost-response modes
- real exact-event retry reconciliation
- TalkBack focus, disabled-state, and hidden-content behavior
- responsive verification at the target device and narrow-screen regression size

This design does not establish:

- the long-term content delivery or audio CDN model
- a general-purpose audio catalog for all rituals
- a production failure-injection feature
- a separate fake UAT state page
- additional visible Interaction Engine input channels
- a full tablet or desktop Ritual Room layout

## Locked Acceptance Content

The Phase 41 acceptance path uses these exact active utterances:

| State | Display ID | English | Chinese support | Audio asset ID |
|---|---|---|---|---|
| READY | `shoes_on_ready_v1` | `Let’s put your shoes on.` | `我们来穿鞋吧。` | `rr_shoes_001` |
| REVISED after “还不想穿” | `shoes_on_revised_wait_v1` | `You don’t want your shoes on yet.` | `你现在还不想穿鞋。` | `rr_shoes_002` |

The internal reaction key remains `not_ready_yet`. It must not appear in:

- visual UI
- semantics or TalkBack announcements
- audio IDs or audio filenames
- user-visible logs or error copy

`Let’s try one shoe together.` is not the Phase 41 D.4.5 default output. It may remain only as a future strategy or alternate line and must not affect the acceptance path.

## Active Utterance Contract

`ProductSnapshot.activeUtterance` is the sole source of the current user-visible utterance identity.

The existing snapshot `utterance` field is migrated rather than retained as a second alias. The value is an immutable `ActiveUtterance` with at least:

```text
displayId
primary
zhSupport
audioAssetId
```

It may also contain presentation-safe fields required by D.4.5, such as:

- optional user-visible context label, for example `还不想穿`
- optional gentle support line, for example `可以先等等。`

It must not contain:

- Flutter asset paths
- reaction keys
- event IDs
- engine event summaries
- strategy rationales
- retry or transport status
- playback state

The UI must not infer audio identity from English text. It reads:

```text
snapshot.activeUtterance.primary
snapshot.activeUtterance.zhSupport
snapshot.activeUtterance.audioAssetId
```

as one coherent projection.

During SUBMITTING and result-not-confirmed states, the prior authoritative `activeUtterance` remains visible. A successful or duplicate-reconciled result replaces the whole snapshot, including the whole active utterance.

## Presentation-Safe Context

`normalizedContext.eventSummary` remains internal engine evidence. Presentation widgets must not read or render it.

The revised context chip comes from presentation-safe data, not from the raw reaction key or an English engine summary. For the accepted path, it displays:

```text
还不想穿
```

Permitted visible English is limited to intended product content:

- `Shoes on.`
- the current active English utterance

Forbidden visual or semantic text includes:

- `unknown-outcome`
- `eventSummary`
- `duplicate_ignored`
- `lost response`
- `retry`
- `not_ready_yet`
- event IDs, revisions, or mode keys
- English engine hypotheses and strategy rationales

## Stable Content and Audio Mapping

The Phase 41 fixture declares:

1. the READY active utterance identity
2. the REVISED acceptance utterance identity
3. a private audio catalog mapping opaque `audioAssetId` values to bundled references
4. the user-visible `听一遍` label

The bundled files use opaque names that do not encode reaction keys:

```text
assets/audio/ritual_room/shoes_on/rr_shoes_001.mp3
assets/audio/ritual_room/shoes_on/rr_shoes_002.mp3
```

The stable content boundary produces two separate outputs:

- presentation-safe room content, with no asset paths
- a data/service-only audio catalog

`RitualRoomMapper` and the repository fail fast when:

- an audio ID is empty or duplicated
- a bundled reference is empty, outside the approved audio asset root, or absent
- READY or the accepted REVISED utterance lacks an audio ID
- either acceptance audio ID has no catalog entry

The content API response is cached so room projection and audio resolution do not require independent fixture reads.

## Audio Architecture

### Port

The UI-facing command boundary is:

```dart
abstract interface class AudioPlaybackPort {
  Future<void> play(String audioAssetId);
  Future<void> stop();
  Future<void> dispose();
}
```

`play` receives only `audioAssetId`.

The UI and `RitualRoomSessionNotifier` must not:

- receive a Flutter asset path
- choose an audio file
- perform a string-to-audio lookup
- instantiate an audio plugin

### Adapter

The Phase 41 adapter:

1. resolves `audioAssetId` through the validated private catalog
2. converts the bundled reference into the plugin-specific source
3. plays the local asset
4. reports completion or failure to the audio controller

The implementation should reuse the repository's established `audioplayers` package pattern, subject to official package documentation verification during implementation.

### Controller State

Transient playback state belongs to an independent lightweight controller/provider:

```text
idle
playing(audioAssetId)
completed(audioAssetId)
failure(audioAssetId)
```

Playback state never enters `ProductSnapshot`.

When the authoritative active utterance changes to a different `audioAssetId`, stale playback is stopped and playback state returns to idle. The new audio is not auto-played; the parent presses `听一遍`.

Playback failure uses low-pressure Chinese copy, for example:

```text
暂时没播放出来，可以再点一次。
```

It does not alter the Ritual Room session state.

## UAT Availability Gate

The gate is fixed:

```dart
const bool.fromEnvironment('BABY_TALK_UAT') && !kReleaseMode
```

The implementation defines one compile-time constant from that expression and uses it for both:

- app-shell overlay composition
- Interaction API decoration

Release behavior is non-negotiable:

- `BABY_TALK_UAT=true` does not enable the harness
- no UAT entry is rendered
- no UAT semantics node exists
- the raw `InteractionApi` is selected
- no fault-injection controller can alter calls
- the production Ritual Room path is unchanged

The constant branch must permit release tree shaking; no runtime preference, route parameter, or remote setting may enable UAT.

## UAT Shell

The harness lives outside the `RitualRoomScreen` product component tree.

An enabled debug/profile build wraps the app child in `UatOverlayHost`. When closed:

- it contributes no layout size
- it contributes no semantics node
- it is absent from TalkBack order
- it does not change Ritual Room state

The QA opener is a shell-level, semantics-excluded gesture available only when the compile-time UAT gate is true. It observes a documented multi-tap gesture in the top-right QA region without adding visible product chrome or consuming normal child gestures.

When opened, the overlay uses Chinese QA labels and offers:

- `正常`
- `延迟成功`
- `提交成功但丢失响应`
- `恢复正常`

`恢复正常` sets injection mode to normal only. It does not reload, roll back, replace, or fabricate the current snapshot.

## Interaction API Decorator

`UatInteractionApiDecorator` wraps the real `InteractionApi`:

```text
Session Notifier
→ InteractionRepository
→ DTO mapper
→ UatInteractionApiDecorator
→ real InteractionApi
→ InteractionEngine
```

It never creates a `ProductSnapshot`.

### Normal

Delegate unchanged and return the real response.

### Delayed Success

1. delegate to the real API
2. receive the real authoritative response
3. hold that response for a bounded UAT delay
4. return it unchanged

The UI remains SUBMITTING while the response is held.

### Commit Succeeded, Response Lost

1. delegate to the real API
2. allow DTO mapping and the real engine to process and commit the event
3. receive a real `AdvanceApplied` response
4. hold the post-commit response for a bounded UAT delay so the device can observe and capture SUBMITTING
5. discard the response after that delay
6. throw `InteractionOutcomeUnknownException(responseLostAfterDispatch)`

No snapshot is fabricated.

The notifier keeps the exact private command and enters the result-not-confirmed state. The next `retryPendingEvent()` call sends:

```text
same InputEvent
same eventId
same interactionId
same expectedRevision
```

The decorator delegates that retry normally. The real engine finds the existing receipt before revision validation and returns `AdvanceDuplicateIgnored` with the authoritative revised snapshot. Repository mapping then moves the notifier to READY with the REVISED active utterance.

“Retry and reconcile successfully” is therefore an observed result, not an injection mode.

## Ritual Room Visual Structure

The screen is rebuilt around the approved D.4.5 hierarchy:

1. compact top bar with `出门小声音`
2. stable side-by-side identity area with the approved parent-child illustration
3. one dominant utterance card
4. current English utterance
5. Chinese support
6. current `听一遍` action
7. one action cue
8. restrained reaction input
9. reassurance and quiet exit

The approved illustration remains:

```text
assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png
```

The four states preserve one screen and one geometry:

| State | Projection |
|---|---|
| READY | READY active utterance and its audio ID |
| SUBMITTING | prior active utterance remains; selected context appears; reactions lock; `正在换一种说法…` appears inline |
| Result not confirmed | prior active utterance remains; reactions stay locked; `刚刚没确认成功，我们再试一次。` and `再试一次` appear |
| REVISED | whole authoritative snapshot replaces the prior one; English, Chinese support, context label, gentle support, and audio ID update together |

The result-not-confirmed state is not an error page.

## Responsive Layout

The primary Android acceptance viewport is:

```text
logical: 427×952dp
physical: 1280×2856px
```

`390×844dp` remains a narrow-phone regression reference only.

Layout decisions use parent constraints through `LayoutBuilder`. They must not use:

- phone/tablet hardware detection
- orientation as a layout proxy
- physical-pixel branching

Rules:

- 427dp always uses the phone single-column layout
- Phase 41 introduces no separate tablet composition
- content is centered and constrained to a maximum width of 430dp
- normal phone horizontal padding is 20dp
- below 400dp, horizontal padding becomes 16dp and the illustration reduces from 112dp to 96dp
- identity and utterance containers use minimum constraints, not fixed heights that can clip text
- the page scrolls vertically when content or text scale requires it
- the additional-reaction sheet is scrollable and bounded to approximately half the available height

At text scale 1.0 and 1.3:

- no English or Chinese content truncates
- the illustration does not overlap text
- controls do not compress below 48dp
- the quiet exit remains reachable
- READY, SUBMITTING, result-not-confirmed, and REVISED remain understandable without horizontal scrolling

## Accessibility Contract

All product controls have at least a 48×48dp hit target.

### More Choices

`更多情况`:

- has a minimum 48dp touch target
- announces only the user-visible Chinese label
- exposes no internal reaction classification
- keeps hidden sheet content out of semantics until the sheet opens

### Locked Reactions

In SUBMITTING and result-not-confirmed states:

- inline reaction controls are visually and semantically disabled
- an already-open reaction sheet updates to disabled semantics
- no disabled reaction can dispatch a new event

### Recovery Focus

On entry to result-not-confirmed:

- the Chinese recovery message is a live-region announcement
- the semantics traversal places `再试一次` before disabled reaction controls
- a dedicated focus controller requests the recovery action after the frame
- real TalkBack verification must confirm that the recovery path receives priority

The acceptance criterion is observed TalkBack behavior, not merely a semantics-tree property.

### Product Language

TalkBack may read intended English product content, including the active utterance. It must not read:

- internal reaction keys
- UAT mode keys
- event IDs or revisions
- `eventSummary`
- unknown-outcome or transport terminology
- audio asset IDs or paths

## Testing Strategy

### Domain and Contract Tests

Prove:

- `ProductSnapshot.activeUtterance` is the only current utterance field
- display ID, English, Chinese support, and audio ID survive engine, DTO, mapper, repository, and replay paths
- the READY and accepted REVISED results have the exact locked content
- `not_ready_yet` never becomes visible copy
- `eventSummary` remains internal and is absent from presentation source

### Content and Mapper Tests

Prove:

- both acceptance audio IDs resolve to bundled references
- bundled files exist
- missing, duplicate, empty, or invalid-root entries fail fast
- READY and REVISED active utterances cannot map without audio
- UI-facing room content exposes no Flutter audio path

### Audio Tests

Unit/fake tests prove:

- `AudioPlaybackPort.play` receives only `audioAssetId`
- READY passes `rr_shoes_001`
- REVISED passes `rr_shoes_002`
- no English-text lookup occurs
- active-audio identity changes stop stale playback
- playing, completion, and failure remain transient

Adapter tests prove:

- both IDs resolve to the correct bundled assets
- plugin-specific asset conversion is correct
- missing IDs fail with a controlled audio error

Device UAT proves both files are audibly playable.

### API Decorator and Reconciliation Tests

Prove:

- normal mode delegates once and preserves the response
- delayed mode delegates to the real API and returns the same response after delay
- lost-response mode calls the real engine first and throws only after a committed applied result
- the notifier enters result-not-confirmed
- retry reuses the identical event envelope
- the real engine returns duplicate ignored
- repository mapping publishes the authoritative REVISED snapshot
- active utterance and audio ID update together
- the decorator never constructs a snapshot

### UAT Gate Tests

Prove:

- flag off: no overlay and raw API
- debug/profile plus flag on: overlay and decorator available
- release plus flag on: gate false, no entry, raw API
- the production provider selects the raw API whenever the gate is false
- the overlay is absent from layout and semantics while closed

In addition to truth-table and provider tests, build a release APK with:

```text
--dart-define=BABY_TALK_UAT=true
```

Install and launch it, then verify that no UAT entry or injection behavior is reachable.

### Widget Tests

Cover:

- `427×952dp` at text scales 1.0 and 1.3
- `390×844dp` narrow-screen regression
- all four acceptance states
- D.4.5 hierarchy and approved illustration
- no internal technical English in visible text or semantics
- active English product content remains permitted
- every interactive target is at least 48dp
- hidden additional choices are absent from semantics
- locked reactions have disabled semantics
- recovery traversal and focus prefer `再试一次`
- playback and quiet exit remain available during reconciliation

### Integration and Device UAT

On the target Android device:

1. build/install a debug or profile APK with `BABY_TALK_UAT=true`
2. confirm logical viewport `427×952dp`
3. capture READY
4. play READY audio
5. select `提交成功但丢失响应` before creating the acceptance event
6. select `还不想穿` exactly once
7. use the lost-response mode's bounded post-commit delay to observe and capture SUBMITTING for that same event
8. allow the decorator to discard that committed event's response and reach result-not-confirmed
9. confirm reactions are disabled and TalkBack prioritizes `再试一次`
10. retry the exact same event
11. observe real duplicate reconciliation
12. capture REVISED
13. play REVISED audio and confirm it differs from READY
14. restore normal injection mode without changing the snapshot

The main acceptance flow must not switch from delayed-success mode to lost-response mode and must not create a second reaction event for screenshot capture. The single lost-response event supplies both SUBMITTING evidence and the later reconciliation evidence.

`延迟成功` remains available only as a separate supplemental run for responsive or timing inspection. It is not part of the exact-event reconciliation acceptance flow.

Record screenshots for:

- READY
- SUBMITTING
- result not confirmed
- REVISED

Run the full TalkBack path and record any focus or announcement deviation.

## Regression Gates

Completion requires:

- `flutter analyze` with zero issues
- the complete `mobile_v2` Flutter test suite
- all existing 122 baseline tests still represented and passing
- all newly added tests passing
- Phase 41 semantic firewall and activation-governor checks still passing
- debug/profile UAT device evidence
- release-with-flag negative evidence

The number `122` is a historical baseline, not a fixed future test total.

## Acceptance Contract

Phase 41 human verification is complete only when the target Android device proves:

```text
READY active utterance + READY audio
→ real reaction submission
→ visible SUBMITTING state
→ real committed event with lost response
→ Chinese result-not-confirmed recovery state
→ exact-event retry
→ engine duplicate reconciliation
→ authoritative REVISED active utterance + REVISED audio
```

No screenshot-only fake state, UI-layer snapshot fabrication, fixed scene-title audio, text-to-audio matching, or release-reachable UAT mechanism can satisfy this contract.
