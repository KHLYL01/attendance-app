import 'package:get/get.dart';

import '../../data/repo/attendance_repository.dart';
import '../../data/repo/calendar_repository.dart';
import '../../data/repo/excel_repository.dart';
import '../../data/repo/student_repository.dart';
import '../attendance/attendance_controller.dart';
import '../dashboard/dashboard_controller.dart';
import '../records/records_controller.dart';
import '../settings/settings_controller.dart';
import '../students/students_controller.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // Levels and the study calendar are shared by every section, so they load first.
    Get.put(SettingsController(Get.find<StudentRepository>(), Get.find<CalendarRepository>()));
    Get.lazyPut(
      () => DashboardController(
        Get.find<StudentRepository>(),
        Get.find<AttendanceRepository>(),
        Get.find<SettingsController>(),
      ),
    );
    Get.lazyPut(
      () => StudentsController(
        Get.find<StudentRepository>(),
        Get.find<AttendanceRepository>(),
        Get.find<ExcelRepository>(),
        Get.find<SettingsController>(),
      ),
    );
    Get.lazyPut(
      () => AttendanceController(
        Get.find<StudentRepository>(),
        Get.find<AttendanceRepository>(),
        Get.find<SettingsController>(),
      ),
    );
    Get.lazyPut(
      () => RecordsController(
        Get.find<AttendanceRepository>(),
        Get.find<ExcelRepository>(),
        Get.find<SettingsController>(),
      ),
    );
    Get.lazyPut(HomeController.new);
  }
}
