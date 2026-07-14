# Phase 41 Riverpod Mapping

## Runnable root

```text
ProviderScope
└─ BabyTalkApp
   ├─ watches RitualRoomSession NotifierProvider
   ├─ watches InteractionCapabilityMask Provider
   ├─ reads InteractionInputFactory Provider in reaction callbacks
   └─ reads RitualRoomSession NotifierProvider for open/submit commands
```

`mobile_v2/lib/main.dart` contains the only `ProviderScope`. `BabyTalkApp`
starts `shoes_on_room_v1` directly. `RitualRoomScreen` receives immutable
state, mask, and callbacks and imports no Riverpod, DTO, mock source, mapper, or
concrete repository.

## Complete read-only provider graph

```text
InteractionClock Provider
Interaction EventIdGenerator Provider
InteractionIdGenerator Provider
InteractionInputFactory Provider
InteractionSeedSource Provider
NormalizeEngine Provider
StateAccumulator Provider
StrategyEngine Provider
UtteranceEngine Provider
InteractionRuntimeStore Provider
InteractionEngine Provider
InteractionEnginePort Provider
InteractionSessionInitializer Provider
InteractionMapper Provider
RitualRoomMapper Provider
RitualContentApi Provider
RitualRoomRepository Provider
InteractionApi Provider
InteractionRepository Provider
InteractionCapabilityMask Provider
```

Every node above is read-only dependency composition. The capability mask is
presentation-only and is not read by engine, API, repository, or session
authority dependencies.

## Sole mutable node

`RitualRoomSession NotifierProvider` is the only mutable Riverpod node. It owns
transient loading, submitting, and recoverable-error orchestration while
carrying whole `RitualRoomContent` and `ProductSnapshot` values. It does not
copy revision, context, memory, strategy, utterance, or raw `InputEvent`
content.

riverpod_read_only_provider_graph=complete

riverpod_mutable_node=RitualRoomSession NotifierProvider

riverpod_mutable_node_uniqueness=only mutable node
