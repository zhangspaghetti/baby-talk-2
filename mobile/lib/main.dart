import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final bootState = await AppBootState.load(rootBundle);
  final overrides = <Override>[];
  if (bootState.isReady && bootState.assetPhraseService != null) {
    overrides.add(
      assetPhraseServiceProvider.overrideWithValue(
        bootState.assetPhraseService!,
      ),
    );
  }
  runApp(
    ProviderScope(
      overrides: overrides,
      child: BabyTalkApp(bootState: bootState),
    ),
  );
}
