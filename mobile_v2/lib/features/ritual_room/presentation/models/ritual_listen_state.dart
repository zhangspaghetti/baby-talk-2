sealed class RitualListenState {
  const RitualListenState();
}

final class RitualListenUnavailable extends RitualListenState {
  const RitualListenUnavailable();
}

final class RitualListenReady extends RitualListenState {
  const RitualListenReady();
}

final class RitualListenLoading extends RitualListenState {
  const RitualListenLoading();
}

final class RitualListenPlaying extends RitualListenState {
  const RitualListenPlaying();
}

final class RitualListenPaused extends RitualListenState {
  const RitualListenPaused();
}

final class RitualListenFailure extends RitualListenState {
  const RitualListenFailure();
}
