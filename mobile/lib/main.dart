import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final bootState = await AppBootState.load(rootBundle);
  runApp(BabyTalkApp(bootState: bootState));
}
