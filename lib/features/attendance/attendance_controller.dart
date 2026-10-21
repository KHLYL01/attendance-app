import 'package:get/get.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/handle_request.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../../data/model/calendar/calendar_models.dart';
import '../../data/model/student/student_model.dart';
import '../../data/repo/attendance_repository.dart';
import '../../data/repo/student_repository.dart';
import '../settings/settings_controller.dart';

/// Taking attendance for one day. Changes stay in memory until the user presses save.
class AttendanceController extends GetxController {
  AttendanceController(this._students, this._attendance, this._settings);

  final StudentRepository _students;
  final AttendanceRepository _attendance;
  final SettingsController _settings;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errMessage = RxnString();

  final date = today().obs;
  final group = const GroupFilter().obs;
  final query = ''.obs;

  final students = <StudentModel>[].obs;
  final entries = <int, AttendanceEntry>{}.obs;
  final dirty = false.obs;

  String get dateText => dateKey(date.value);

  List<LevelModel> get levels => _settings.levels;

  WorkCalendar get calendar => _settings.calendar.value;

  /// Attendance can only be taken on study days.
  bool get isWorkingDay => calendar.isWorkingDay(date.value);

  HolidayModel? get holiday => calendar.holidayOn(dateText);

  List<StudentModel> get visible {
    final text = query.value.trim().toLowerCase();
    if (text.isEmpty) return students;
    return students
        .where((student) => student.name.toLowerCase().contains(text) || student.code.toLowerCase().contains(text))
        .toList();
  }

  int count(AttendanceStatus status) {
    return students.where((student) => entries[student.id]?.status == status).length;
  }

  int get unmarked => students.where((student) => entries[student.id]?.status == null).length;

  Future<void> load() async {
    await handleRequest(
      () => _students.students(group: group.value),
      isLoading: isLoading,
      errMessage: errMessage,
      onSuccess: (items) async {
        final day = await _attendance.day(dateText);
        day.fold((_) {}, (records) {
          entries.assignAll({
            for (final student in items)
              if (records[student.id] case final record?)
                student.id!: AttendanceEntry(record.status, note: record.note),
          });
        });
        students.assignAll(items);
        dirty.value = false;
      },
    );
  }

  void setStatus(int studentId, AttendanceStatus? status) {
    entries[studentId] = AttendanceEntry(status, note: entries[studentId]?.note);
    dirty.value = true;
  }

  void setNote(int studentId, String? note) {
    entries[studentId] = AttendanceEntry(entries[studentId]?.status, note: note);
    dirty.value = true;
  }

  /// Gives every student without a status the given one; already-marked students are kept.
  void markRest(AttendanceStatus status) {
    for (final student in students) {
      if (entries[student.id]?.status == null) {
        entries[student.id!] = AttendanceEntry(status, note: entries[student.id]?.note);
      }
    }
    dirty.value = true;
  }

  Future<void> changeDate(DateTime value) async {
    if (!await confirmLeave()) return;
    final day = DateTime(value.year, value.month, value.day);
    // Attendance is never taken ahead of time.
    date.value = day.isAfter(today()) ? today() : day;
    await load();
  }

  /// False on today: there is no later day to take attendance for.
  bool get canGoForward => date.value.isBefore(today());

  /// Moves to the previous or next study day, skipping weekends and holidays.
  Future<void> shiftDay(int step) async {
    var day = date.value;
    for (var i = 0; i < 60; i++) {
      day = DateTime(day.year, day.month, day.day + step);
      if (day.isAfter(today())) return;
      if (calendar.isWorkingDay(day)) break;
    }
    await changeDate(day);
  }

  Future<void> changeGroup(GroupFilter value) async {
    if (!await confirmLeave()) return;
    group.value = value;
    await load();
  }

  Future<void> save() async {
    final day = dateText;
    final changes = {for (final student in students) student.id!: entries[student.id] ?? const AttendanceEntry(null)};
    await handleRequest(
      () => _attendance.saveDay(day, changes),
      isLoading: isSaving,
      errMessage: errMessage,
      successMessage: 'Attendance saved'.tr,
      onSuccess: (_) => dirty.value = false,
    );
  }

  /// Asks before throwing away marks that were not saved. True means it is fine to continue.
  Future<bool> confirmLeave() async {
    if (!dirty.value) return true;
    final choice = await unsavedChangesDialog();
    switch (choice) {
      case UnsavedChoice.save:
        await save();
        return !dirty.value;
      case UnsavedChoice.discard:
        dirty.value = false;
        return true;
      case null:
        return false;
    }
  }
}
