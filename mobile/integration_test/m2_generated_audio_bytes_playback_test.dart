import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android BytesSource completes six controlled MP3 payloads', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final output = AudioplayersCareAudioOutput();

      try {
        for (final assetPath in _controlledMp3Assets) {
          final asset = await rootBundle.load(assetPath);
          final bytes = Uint8List.view(
            asset.buffer,
            asset.offsetInBytes,
            asset.lengthInBytes,
          );
          final completed = output.completionStream.first.timeout(
            const Duration(seconds: 15),
          );

          await output.playBytes(bytes, 'audio/mpeg');
          await completed;
        }
      } finally {
        await output.dispose();
      }
    });
  });
}

const _controlledMp3Assets = <String>[
  'assets/audio/phrases/bath_time_warm_water.mp3',
  'assets/audio/phrases/bath_time_splash_splash.mp3',
  'assets/audio/phrases/bath_time_all_clean.mp3',
  'assets/audio/phrases/diaper_change_clean_bottom.mp3',
  'assets/audio/phrases/diaper_change_all_dry.mp3',
  'assets/audio/phrases/feeding_time_open_wide.mp3',
];
