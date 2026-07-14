abstract interface class InteractionClock {
  DateTime now();
}

final class SystemInteractionClock implements InteractionClock {
  const SystemInteractionClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
