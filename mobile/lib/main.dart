import 'package:baby_talk_mobile/app.dart';
import 'package:baby_talk_mobile/data/app_local_store.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BabyTalkApp(localStore: const SharedPreferencesAppLocalStore()));
}
