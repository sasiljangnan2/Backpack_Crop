import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  Intl.defaultLocale = 'ko_KR';
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  services = await AppServices.create();
  await services.push.initialize();
  runApp(const BackpackApp());
  await services.auth.restore();
}
