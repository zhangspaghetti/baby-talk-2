abstract interface class InteractionIdGenerator {
  String generate();
}

final class IncrementingInteractionIdGenerator
    implements InteractionIdGenerator {
  IncrementingInteractionIdGenerator({this.prefix = 'interaction'});

  final String prefix;
  int _nextValue = 1;

  @override
  String generate() => '$prefix-${_nextValue++}';
}
