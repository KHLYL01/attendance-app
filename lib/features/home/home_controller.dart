import 'package:get/get.dart';

import '../attendance/attendance_controller.dart';
import '../dashboard/dashboard_controller.dart';
import '../records/records_controller.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../students/students_controller.dart';

abstract final class HomeSection {
  static const int dashboard = 0;
  static const int students = 1;
  static const int attendance = 2;
  static const int records = 3;
}

class HomeController extends GetxController {
  final section = HomeSection.dashboard.obs;

  @override
  void onReady() {
    super.onReady();
    _reload(section.value);
  }

  Future<void> selectSection(int index) async {
    if (index == section.value) return;
    if (section.value == HomeSection.attendance && !await Get.find<AttendanceController>().confirmLeave()) {
      return;
    }
    section.value = index;
    _reload(index);
  }

  Future<void> openSettings() async {
    if (section.value == HomeSection.attendance && !await Get.find<AttendanceController>().confirmLeave()) {
      return;
    }
    final settings = Get.find<SettingsController>();
    settings.load();
    await Get.to(() => const SettingsPage());
    await settings.load();
    _reload(section.value);
  }

  /// Every section reads straight from the database when it is opened, so changes made
  /// in one section show up in the others.
  void _reload(int index) {
    switch (index) {
      case HomeSection.dashboard:
        Get.find<DashboardController>().load();
      case HomeSection.students:
        Get.find<StudentsController>().load();
      case HomeSection.attendance:
        Get.find<AttendanceController>().load();
      case HomeSection.records:
        Get.find<RecordsController>().load();
    }
  }
}
