import 'package:get/get.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/excel_actions.dart';
import '../../core/utils/handle_request.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../../data/model/student/student_model.dart';
import '../../data/repo/attendance_repository.dart';
import '../../data/repo/excel_repository.dart';
import '../settings/settings_controller.dart';

enum RecordsView { records, summary }

class RecordsController extends GetxController {
  RecordsController(this._attendance, this._excel, this._settings);

  final AttendanceRepository _attendance;
  final SettingsController _settings;
  final ExcelRepository _excel;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isExcelBusy = false.obs;
  final errMessage = RxnString();

  final view = RecordsView.records.obs;
  final from = Rxn<DateTime>(DateTime(today().year, today().month));
  final to = Rxn<DateTime>(today());
  final group = const GroupFilter().obs;
  final statusFilter = Rxn<AttendanceStatus>();
  final query = ''.obs;

  final records = <AttendanceRecord>[].obs;
  final summary = <AttendanceSummary>[].obs;

  AttendanceFilter get filter => AttendanceFilter(
    from: from.value == null ? null : dateKey(from.value!),
    to: to.value == null ? null : dateKey(to.value!),
    group: group.value,
    status: statusFilter.value,
  );

  List<LevelModel> get levels => _settings.levels;

  /// Records on other days are kept but left out of every rate.
  bool isStudyDay(String date) => _settings.calendar.value.isWorkingKey(date);

  /// Today if it is a study day, otherwise the most recent one.
  DateTime lastStudyDay() {
    var day = today();
    for (var i = 0; i < 60 && !_settings.calendar.value.isWorkingDay(day); i++) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return day;
  }

  List<AttendanceRecord> get filteredRecords {
    final text = query.value.trim().toLowerCase();
    if (text.isEmpty) return records;
    return records.where((record) => _hit(text, [record.studentName, record.studentCode, record.note])).toList();
  }

  List<AttendanceSummary> get filteredSummary {
    final text = query.value.trim().toLowerCase();
    if (text.isEmpty) return summary;
    return summary.where((item) => _hit(text, [item.name, item.code])).toList();
  }

  bool _hit(String text, List<String?> values) {
    return values.whereType<String>().any((value) => value.toLowerCase().contains(text));
  }

  Future<void> load() async {
    final current = filter;
    await handleRequest(
      () => _attendance.records(current),
      isLoading: isLoading,
      errMessage: errMessage,
      onSuccess: records.assignAll,
    );
    // The summary ignores the status filter: it always counts every status.
    final totals = await _attendance.summary(
      AttendanceFilter(from: current.from, to: current.to, group: current.group),
    );
    totals.fold((_) {}, summary.assignAll);
  }

  Future<void> setPeriod(DateTime? start, DateTime? end) {
    from.value = start;
    to.value = end;
    return load();
  }

  Future<void> setGroup(GroupFilter value) {
    group.value = value;
    return load();
  }

  Future<void> setStatus(AttendanceStatus? status) {
    statusFilter.value = status;
    return load();
  }

  Future<bool> updateRecord(AttendanceRecord record) async {
    var saved = false;
    await handleRequest(
      () => _attendance.update(record),
      isLoading: isSaving,
      errMessage: errMessage,
      successMessage: 'Saved'.tr,
      onSuccess: (_) async {
        saved = true;
        await load();
      },
    );
    return saved;
  }

  Future<bool> deleteRecord(int id) async {
    var deleted = false;
    await handleRequest(
      () => _attendance.delete(id),
      isLoading: isSaving,
      errMessage: errMessage,
      successMessage: 'Deleted'.tr,
      onSuccess: (_) async {
        deleted = true;
        await load();
      },
    );
    return deleted;
  }

  Future<void> downloadTemplate(DateTime date) {
    final day = dateKey(date);
    return deliverExcel(
      () => _excel.attendanceTemplate(date: day, group: group.value),
      'attendance_template_$day.xlsx',
      busy: isExcelBusy,
    );
  }

  Future<void> exportRecords() {
    final current = filter;
    final period = [current.from ?? 'start', current.to ?? 'end'].join('_');
    return deliverExcel(() => _excel.attendanceExport(current), 'attendance_$period.xlsx', busy: isExcelBusy);
  }

  Future<void> importRecords() async {
    if (await importExcel(_excel.importAttendance, busy: isExcelBusy)) await load();
  }
}
