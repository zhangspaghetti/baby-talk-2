import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';

void main() {
  test('care audio coordinator is shared for provider container lifetime', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(careAudioSessionCoordinatorProvider);
    final second = container.read(careAudioSessionCoordinatorProvider);

    expect(second, same(first));
  });
}
