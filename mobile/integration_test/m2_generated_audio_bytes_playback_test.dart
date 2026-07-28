import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android BytesSource completes an MP3 generated-audio payload', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final asset = await rootBundle.load(
        'assets/audio/phrases/bath_time_warm_water.mp3',
      );
      final bytes = Uint8List.view(
        asset.buffer,
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      final output = AudioplayersCareAudioOutput();
      final completed = output.completionStream.first.timeout(
        const Duration(seconds: 15),
      );

      try {
        await output.playBytes(bytes, 'audio/mpeg');
        await completed;
      } finally {
        await output.dispose();
      }
    });
  });
}
