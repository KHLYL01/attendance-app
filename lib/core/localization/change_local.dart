import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/app_keys.dart';

class LocalController extends GetxController {
  LocalController(this._prefs);

  final SharedPreferences _prefs;

  Locale? language;

  @override
  void onInit() {
    super.onInit();
    language = const Locale('ar');
    _prefs.setString(AppKeys.language, 'ar');
  }
}
