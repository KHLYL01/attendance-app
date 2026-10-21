import 'package:get/get.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/excel_actions.dart';
import '../../core/utils/handle_request.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../../data/model/student/student_model.dart';
import '../../data/repo/attendance_repository.dart';
import '../../data/repo/excel_repository.dart';
import '../../data/repo/student_repository.dart';
import '../settings/settings_controller.dart';

enum StatsPeriod { month, level }

/// What the side panel (or pushed page on phones) shows.
enum StudentPanel { none, details, form }

/// One student's attendance over the chosen period, counting working days only.
class StudentStats {
  const StudentStats({required this.summary, required this.workingDays, required this.from, required this.recent});

  final AttendanceSummary summary;

  /// Study days in the period up to today, whether or not attendance was taken.
  final int workingDays;
  final String from;
  final List<AttendanceRecord> recent;

  int get unrecorded => (workingDays - summary.total).clamp(0, workingDays);
}

class StudentsController extends GetxController {
  StudentsController(this._repository, this._attendance, this._excel, this._settings);

  final StudentRepository _repository;
  final AttendanceRepository _attendance;
  final ExcelRepository _excel;
  final SettingsController _settings;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isExcelBusy = false.obs;
  final statsLoading = false.obs;
  final errMessage = RxnString();

  final students = <StudentModel>[].obs;
  final group = const GroupFilter().obs;
  final query = ''.obs;

  final panel = StudentPanel.none.obs;
  final selected = Rxn<StudentModel>();
  final period = StatsPeriod.month.obs;
  final stats = Rxn<StudentStats>();

  List<LevelModel> get levels => _settings.levels;

  List<StudentModel> get filtered {
    final text = query.value.trim().toLowerCase();
    return students.where((student) {
      if (!group.value.matches(student)) return false;
      if (text.isEmpty) return true;
      return student.name.toLowerCase().contains(text) || student.code.contains(text);
    }).toList();
  }

  Future<void> load() async {
    await handleRequest(
      _repository.students,
      isLoading: isLoading,
      errMessage: errMessage,
      onSuccess: students.assignAll,
    );
  }

  // ─── Panel ────────────────────────────────────────────────────────────────

  Future<void> showDetails(StudentModel student) async {
    selected.value = student;
    panel.value = StudentPanel.details;
    await loadStats();
  }

  void showForm(StudentModel? student) {
    selected.value = student;
    panel.value = StudentPanel.form;
  }

  void closePanel() {
    panel.value = StudentPanel.none;
    selected.value = null;
    stats.value = null;
  }

  Future<void> setPeriod(StatsPeriod value) {
    period.value = value;
    return loadStats();
  }

  Future<void> loadStats() async {
    final student = selected.value;
    if (student?.id == null) return;
    final end = today();
    final start = period.value == StatsPeriod.month
        ? DateTime(end.year, end.month)
        : parseDate(student!.levelSince) ?? parseDate(await _attendance.firstDate(student.id!)) ?? end;
    final filter = AttendanceFilter(from: dateKey(start), to: dateKey(end), studentId: student!.id);
    statsLoading.value = true;
    try {
      final summary = await _attendance.summary(filter);
      final records = await _attendance.records(filter);
      if (selected.value?.id != student.id) return;
      final calendar = _settings.calendar.value;
      stats.value = summary.fold((_) => null, (items) {
        if (items.isEmpty) return null;
        return StudentStats(
          summary: items.first,
          workingDays: calendar.workingDaysBetween(start, end),
          from: dateKey(start),
          recent: records.fold(
            (_) => const [],
            (list) => list.where((r) => calendar.isWorkingKey(r.date)).take(30).toList(),
          ),
        );
      });
    } finally {
      statsLoading.value = false;
    }
  }

  // ─── Saving ───────────────────────────────────────────────────────────────

  /// Returns the saved student (with its new number when added), or null.
  Future<StudentModel?> save(StudentModel student) async {
    StudentModel? saved;
    await handleRequest(
      () => _repository.save(student),
      isLoading: isSaving,
      errMessage: errMessage,
      successMessage: student.id == null ? 'Student added'.tr : 'Saved'.tr,
      onSuccess: (value) async {
        await load();
        saved = students.firstWhereOrNull((item) => item.id == value.id) ?? value;
      },
    );
    return saved;
  }

  Future<bool> delete(int id) async {
    var deleted = false;
    await handleRequest(
      () => _repository.delete(id),
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

  Future<String> nextNumber() => _repository.nextCode();

  // ─── Excel ────────────────────────────────────────────────────────────────

  Future<void> downloadTemplate() {
    return deliverExcel(_excel.studentsTemplate, 'students_template.xlsx', busy: isExcelBusy);
  }

  Future<void> exportStudents() {
    return deliverExcel(
      () => _excel.studentsExport(group: group.value),
      ExcelRepository.fileName('students'),
      busy: isExcelBusy,
    );
  }

  Future<void> importStudents() async {
    if (await importExcel(_excel.importStudents, busy: isExcelBusy)) {
      await load();
      await _settings.load();
    }
  }
}
