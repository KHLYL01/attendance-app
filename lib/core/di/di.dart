import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/repo/attendance_repository.dart';
import '../../data/repo/calendar_repository.dart';
import '../../data/repo/excel_repository.dart';
import '../../data/repo/student_repository.dart';
import '../localization/change_local.dart';
import '../utils/shared_pref.dart';

Future<void> di() async {
  final preferences = await SharedPreferences.getInstance();
  prefs = preferences;

  Get.put<SharedPreferences>(preferences, permanent: true);
  Get.put<LocalController>(LocalController(preferences), permanent: true);

  final database = await AppDatabase.open();
  registerRepositories(database);
}

/// Shared with the tests, which pass an in-memory database.
void registerRepositories(AppDatabase database) {
  Get.put<AppDatabase>(database, permanent: true);
  Get.lazyPut(() => StudentRepository(Get.find<AppDatabase>()), fenix: true);
  Get.lazyPut(() => CalendarRepository(Get.find<AppDatabase>()), fenix: true);
  Get.lazyPut(() => AttendanceRepository(Get.find<AppDatabase>(), Get.find<CalendarRepository>()), fenix: true);
  Get.lazyPut(
    () => ExcelRepository(
      Get.find<StudentRepository>(),
      Get.find<AttendanceRepository>(),
      Get.find<CalendarRepository>(),
    ),
    fenix: true,
  );
}
