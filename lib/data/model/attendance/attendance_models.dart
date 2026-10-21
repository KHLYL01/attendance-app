import '../common/json_parse.dart';
import '../student/student_model.dart';

enum AttendanceStatus {
  present('PRESENT', 'حاضر', 'ح'),
  absent('ABSENT', 'غائب', 'غ'),
  late('LATE', 'متأخر', 'ت'),
  excused('EXCUSED', 'بعذر', 'ع');

  const AttendanceStatus(this.value, this.label, this.short);

  /// Stored in the database.
  final String value;

  /// Written to and read from Excel.
  final String label;

  /// One letter used in the monthly sheet.
  final String short;

  /// Counts as attending when computing the attendance rate.
  bool get attended => this == present || this == late;

  static AttendanceStatus? fromValue(String? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }

  /// Accepts what people type in Excel: Arabic words, letters, English words or 1/0.
  static AttendanceStatus? parse(String? text) {
    final value = text?.trim().toLowerCase().replaceAll('ـ', '');
    if (value == null || value.isEmpty) return null;
    return switch (value) {
      'حاضر' || 'حاضرة' || 'ح' || 'present' || 'p' || '1' || '✓' => present,
      'غائب' || 'غائبة' || 'غ' || 'absent' || 'a' || '0' || '✗' => absent,
      'متأخر' || 'متاخر' || 'متأخرة' || 'متاخرة' || 'تأخير' || 'ت' || 'late' || 'l' => late,
      'بعذر' ||
      'غائب بعذر' ||
      'غياب بعذر' ||
      'مجاز' ||
      'إجازة' ||
      'اجازة' ||
      'عذر' ||
      'ع' ||
      'excused' ||
      'e' => excused,
      _ => null,
    };
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.note,
    this.studentCode,
    this.studentName,
    this.levelName,
    this.gender,
  });

  final int? id;
  final int studentId;

  /// yyyy-MM-dd
  final String date;
  final AttendanceStatus status;
  final String? note;

  // Joined from the students table for lists and exports.
  final String? studentCode;
  final String? studentName;
  final String? levelName;
  final Gender? gender;

  String get groupLabel => [levelName, gender?.label].whereType<String>().join(' · ');

  factory AttendanceRecord.fromRow(Map<String, dynamic> row) {
    return AttendanceRecord(
      id: asInt(row['id']),
      studentId: asInt(row['student_id']) ?? 0,
      date: asString(row['date']) ?? '',
      status: AttendanceStatus.fromValue(asString(row['status'])) ?? AttendanceStatus.absent,
      note: asString(row['note']),
      studentCode: asString(row['code']),
      studentName: asString(row['name']),
      levelName: asString(row['level_name']),
      gender: Gender.fromValue(asString(row['gender'])),
    );
  }
}

/// The status picked for one student on one day. A null status clears the record.
class AttendanceEntry {
  const AttendanceEntry(this.status, {this.note});

  final AttendanceStatus? status;
  final String? note;
}

class AttendanceFilter {
  const AttendanceFilter({this.from, this.to, this.group = const GroupFilter(), this.status, this.studentId});

  final String? from;
  final String? to;
  final GroupFilter group;
  final AttendanceStatus? status;
  final int? studentId;

  bool get isEmpty => from == null && to == null && group.isEmpty && status == null && studentId == null;
}

/// Per-student totals over a period.
class AttendanceSummary {
  const AttendanceSummary({
    required this.studentId,
    required this.code,
    required this.name,
    this.levelName,
    this.gender,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.excused = 0,
  });

  final int studentId;
  final String code;
  final String name;
  final String? levelName;
  final Gender? gender;
  final int present;
  final int absent;
  final int late;
  final int excused;

  int get total => present + absent + late + excused;

  /// Percentage of recorded days the student attended (present or late).
  double get rate => total == 0 ? 0 : (present + late) * 100 / total;

  /// Percentage of recorded days the student was absent without an excuse.
  double get absenceRate => total == 0 ? 0 : absent * 100 / total;

  String get groupLabel => [levelName, gender?.label].whereType<String>().join(' · ');

  factory AttendanceSummary.fromRow(Map<String, dynamic> row) {
    return AttendanceSummary(
      studentId: asInt(row['id']) ?? 0,
      code: asString(row['code']) ?? '',
      name: asString(row['name']) ?? '',
      levelName: asString(row['level_name']),
      gender: Gender.fromValue(asString(row['gender'])),
      present: asInt(row['present']) ?? 0,
      absent: asInt(row['absent']) ?? 0,
      late: asInt(row['late']) ?? 0,
      excused: asInt(row['excused']) ?? 0,
    );
  }
}

/// Status counts for one day.
class DayCounts {
  const DayCounts(this.counts);

  final Map<AttendanceStatus, int> counts;

  int of(AttendanceStatus status) => counts[status] ?? 0;

  int get total => counts.values.fold(0, (sum, value) => sum + value);
}
