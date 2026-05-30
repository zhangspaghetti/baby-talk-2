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
  runApp(
    ProviderScope(
      overrides: [
        assetPhraseServiceProvider.overrideWithValue(
          bootState.assetPhraseService!,
        ),
      ],
      child: BabyTalkApp(bootState: bootState),
    ),
  );
}
