import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/animations/app_motion.dart';
import 'core/config/app_config.dart';
import 'core/di/di.dart';
import 'core/localization/change_local.dart';
import 'core/localization/translation.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  await di();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LocalController>();

    return GetMaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      translations: MyTranslation(),
      locale: controller.language ?? const Locale('ar'),
      fallbackLocale: const Locale('ar'),
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light,
      defaultTransition: Transition.fadeIn,
      transitionDuration: AppMotion.medium,
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
    );
  }
}
