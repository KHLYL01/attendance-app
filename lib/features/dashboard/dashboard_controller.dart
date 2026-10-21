import 'package:get/get.dart';

import '../../core/utils/date_format.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../../data/repo/attendance_repository.dart';
import '../../data/repo/student_repository.dart';
import '../settings/settings_controller.dart';

class DashboardController extends GetxController {
  DashboardController(this._students, this._attendance, this._settings);

  final StudentRepository _students;
  final AttendanceRepository _attendance;
  final SettingsController _settings;

  final ready = false.obs;
  final studentCount = 0.obs;
  final todayCounts = const DayCounts({}).obs;
  final monthSummary = <AttendanceSummary>[].obs;

  int get levelCount => _settings.levels.length;

  bool get todayIsWorking => _settings.calendar.value.isWorkingDay(today());

  String? get todayHoliday => _settings.calendar.value.holidayOn(dateKey(today()))?.name;

  /// This month's attendance rate for each level and group, in level order.
  List<(String, double?, int)> get groupRates {
    final groups = <String, List<AttendanceSummary>>{};
    for (final item in monthSummary) {
      groups.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    return [for (final entry in groups.entries) (entry.key, _rate(entry.value), entry.value.length)];
  }

  static double? _rate(List<AttendanceSummary> items) {
    var attended = 0;
    var total = 0;
    for (final item in items) {
      attended += item.present + item.late;
      total += item.total;
    }
    return total == 0 ? null : attended * 100 / total;
  }

  /// Attendance rate over this month across every recorded study day.
  double get monthRate {
    var attended = 0;
    var total = 0;
    for (final item in monthSummary) {
      attended += item.present + item.late;
      total += item.total;
    }
    return total == 0 ? 0 : attended * 100 / total;
  }

  /// Students with the most absences this month (excused absences not counted).
  List<AttendanceSummary> get mostAbsent {
    final items = monthSummary.where((item) => item.absent > 0).toList()..sort((a, b) => b.absent.compareTo(a.absent));
    return items.take(5).toList();
  }

  Future<void> load() async {
    final now = today();
    try {
      studentCount.value = await _students.count();
      (await _attendance.dayCounts(dateKey(now))).fold((_) {}, (counts) => todayCounts.value = counts);
      final month = AttendanceFilter(from: dateKey(DateTime(now.year, now.month)), to: dateKey(now));
      (await _attendance.summary(month)).fold((_) {}, monthSummary.assignAll);
    } finally {
      ready.value = true;
    }
  }
}
