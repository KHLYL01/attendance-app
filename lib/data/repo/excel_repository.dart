import 'package:dartz/dartz.dart';
import 'package:excel/excel.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/handle_local_request.dart';
import '../excel/excel_workbook.dart';
import '../local/failures.dart';
import '../model/attendance/attendance_models.dart';
import '../model/common/import_report.dart';
import '../model/student/student_model.dart';
import 'attendance_repository.dart';
import 'calendar_repository.dart';
import 'student_repository.dart';

/// Builds the Excel templates and exports, and imports filled templates back.
///
/// Students and attendance use two separate templates: students must exist before their
/// attendance can be imported, and attendance rows find their student by the student number.
class ExcelRepository {
  ExcelRepository(this._students, this._attendance, this._calendar);

  final StudentRepository _students;
  final AttendanceRepository _attendance;
  final CalendarRepository _calendar;

  static const _codeAliases = ['الرقم', 'رقم', 'الرقم المميز', 'code', 'id'];
  static const _genderAliases = ['الجنس', 'ذكور/إناث', 'group', 'gender'];

  static const studentColumns = [
    ExcelColumn('code', 'رقم الطالب', width: 14, aliases: _codeAliases),
    ExcelColumn('name', 'اسم الطالب', required: true, width: 32, aliases: ['الاسم', 'الاسم الكامل', 'name']),
    ExcelColumn('level', 'المستوى', required: true, width: 18, aliases: ['level']),
    ExcelColumn('gender', 'المجموعة', required: true, width: 12, aliases: _genderAliases),
  ];

  static const attendanceColumns = [
    ExcelColumn('code', 'رقم الطالب', required: true, width: 14, aliases: _codeAliases),
    ExcelColumn('name', 'اسم الطالب', width: 32, aliases: ['الاسم', 'name']),
    ExcelColumn('level', 'المستوى', width: 18, aliases: ['level']),
    ExcelColumn('gender', 'المجموعة', width: 12, aliases: _genderAliases),
    ExcelColumn('date', 'التاريخ', required: true, width: 16, aliases: ['اليوم', 'date']),
    ExcelColumn('status', 'الحالة', required: true, width: 14, aliases: ['الحضور', 'status']),
    ExcelColumn('note', 'ملاحظات', width: 30, aliases: ['ملاحظة', 'notes', 'note']),
  ];

  static const _studentsSheet = 'الطلاب';
  static const _attendanceSheet = 'الحضور';
  static const _summarySheet = 'الملخص';
  static const _matrixSheet = 'كشف الحضور';
  static const _helpSheet = 'التعليمات';
  static const _listsSheet = 'القوائم';

  static String get _statusList => AttendanceStatus.values.map((status) => status.label).join(' / ');

  // ─── Students ─────────────────────────────────────────────────────────────

  Future<Either<Failure, List<int>>> studentsTemplate() {
    return handleLocal(() async {
      final levels = await _levels();
      final excel = ExcelWorkbook.create();
      ExcelWorkbook.addTable(excel, _studentsSheet, studentColumns, const []);
      ExcelWorkbook.addNotes(excel, _helpSheet, [
        'طريقة تعبئة قالب الطلاب',
        '1. اكتب كل طالب في سطر واحد في ورقة "$_studentsSheet" بدءاً من السطر الثاني.',
        '2. اترك عمود "رقم الطالب" فارغاً للطلاب الجدد؛ التطبيق يعطي كل طالب رقماً مميزاً تلقائياً.',
        '3. لتعديل طالب موجود اكتب رقمه (من ملف تصدير الطلاب) وسيتم تحديث اسمه أو مستواه أو مجموعته.',
        '4. عمود "المستوى" إحدى القيم: ${levels.map((level) => level.name).join(' / ')}.',
        '5. عمود "المجموعة": ذكور أو إناث.',
        '6. لا تغيّر أسماء الأعمدة في السطر الأول، واحفظ الملف بصيغة .xlsx ثم استورده من شاشة الطلاب.',
      ]);
      _addLists(excel, levels);
      return ExcelWorkbook.encode(excel, _studentsSheet);
    });
  }

  Future<Either<Failure, List<int>>> studentsExport({GroupFilter group = const GroupFilter()}) {
    return handleLocal(() async {
      final students = (await _students.students(group: group)).fold((f) => throw f, (data) => data);
      final excel = ExcelWorkbook.create();
      ExcelWorkbook.addTable(excel, _studentsSheet, studentColumns, [
        for (final student in students)
          [
            TextCellValue(student.code),
            TextCellValue(student.name),
            ExcelWorkbook.text(student.levelName),
            TextCellValue(student.gender.label),
          ],
      ]);
      _addLists(excel, await _levels());
      return ExcelWorkbook.encode(excel, _studentsSheet);
    });
  }

  /// Rows without a number become new students with automatic numbers; rows with a known
  /// number update that student.
  Future<Either<Failure, ImportReport>> importStudents(List<int> bytes) {
    return handleLocal(() async {
      final rows = ExcelWorkbook.read(bytes, studentColumns);
      final levels = await _levels();
      final known = (await _students.students()).fold((f) => throw f, (data) => data);
      final byCode = {for (final student in known) student.code: student};
      final byName = {for (final student in known) _identity(student.name, student.levelId, student.gender): student};
      final errors = <String>[];
      final seenCodes = <String, int>{};
      final seenNames = <String, int>{};
      final valid = <StudentModel>[];
      for (final row in rows) {
        final code = row['code'];
        final name = row['name'];
        if (name == null) {
          errors.add('السطر ${row.number}: اسم الطالب فارغ');
          continue;
        }
        final level = matchLevel(row['level'], levels);
        if (level == null) {
          final names = levels.map((item) => item.name).join(' / ');
          errors.add(
            row['level'] == null
                ? 'السطر ${row.number}: المستوى فارغ، استخدم: $names'
                : 'السطر ${row.number}: المستوى "${row['level']}" غير معروف، استخدم: $names',
          );
          continue;
        }
        final gender = Gender.parse(row['gender']);
        if (gender == null) {
          errors.add(
            row['gender'] == null
                ? 'السطر ${row.number}: المجموعة فارغة، استخدم: ذكور أو إناث'
                : 'السطر ${row.number}: المجموعة "${row['gender']}" غير معروفة، استخدم: ذكور أو إناث',
          );
          continue;
        }
        if (code != null) {
          if (!byCode.containsKey(code)) {
            errors.add('السطر ${row.number}: لا يوجد طالب بالرقم ${ltr(code)} — اترك الرقم فارغاً لإضافة طالب جديد');
            continue;
          }
          if (seenCodes.containsKey(code)) {
            errors.add('السطر ${row.number}: الرقم ${ltr(code)} مكرر (ورد في السطر ${seenCodes[code]})');
            continue;
          }
          seenCodes[code] = row.number;
        } else {
          // Guards against importing the same filled template twice.
          final identity = _identity(name, level.id!, gender);
          final existing = byName[identity];
          if (existing != null) {
            errors.add('السطر ${row.number}: الطالب "$name" موجود مسبقاً في نفس المجموعة برقم ${existing.code}');
            continue;
          }
          if (seenNames.containsKey(identity)) {
            errors.add('السطر ${row.number}: الطالب "$name" مكرر (ورد في السطر ${seenNames[identity]})');
            continue;
          }
          seenNames[identity] = row.number;
        }
        valid.add(StudentModel(code: code ?? '', name: name, levelId: level.id!, gender: gender));
      }
      if (valid.isEmpty && errors.isEmpty) throw const LocalFailure('The file has no rows to import');
      final (added, updated) = (await _students.upsertMany(valid)).fold((f) => throw f, (data) => data);
      return ImportReport(added: added, updated: updated, errors: errors);
    });
  }

  // ─── Attendance ───────────────────────────────────────────────────────────

  /// The attendance template comes filled with the current students and the chosen date,
  /// so the user only types a status next to each name.
  Future<Either<Failure, List<int>>> attendanceTemplate({
    required String date,
    GroupFilter group = const GroupFilter(),
  }) {
    return handleLocal(() async {
      if (!(await _calendar.calendar()).isWorkingKey(date)) throw const LocalFailure('This day is not a study day');
      final students = (await _students.students(group: group)).fold((f) => throw f, (data) => data);
      final excel = ExcelWorkbook.create();
      ExcelWorkbook.addTable(excel, _attendanceSheet, attendanceColumns, [
        for (final student in students)
          [
            TextCellValue(student.code),
            TextCellValue(student.name),
            ExcelWorkbook.text(student.levelName),
            TextCellValue(student.gender.label),
            TextCellValue(date),
            null,
            null,
          ],
      ]);
      ExcelWorkbook.addNotes(excel, _helpSheet, [
        'طريقة تعبئة قالب الحضور',
        '1. القالب يحتوي على الطلاب المسجّلين حالياً في التطبيق. أضف الطلاب الجدد أولاً من شاشة الطلاب.',
        '2. اكتب في عمود "الحالة" إحدى القيم: $_statusList (أو اختصارها: ح / غ / ت / ع).',
        '3. اكتب التاريخ بالشكل 2026-10-18. يمكنك نسخ الأسطر لتسجيل أكثر من يوم.',
        '4. الربط يتم عبر "رقم الطالب"؛ أعمدة الاسم والمستوى والمجموعة للتوضيح فقط.',
        '5. الأسطر التي تُترك حالتها فارغة يتم تجاهلها.',
        '6. إذا كان للطالب سجل في نفس التاريخ فسيتم استبداله بالقيمة الجديدة.',
        '7. أيام العطل وأيام عدم الدوام تُرفض ولا تُحسب في الحضور.',
      ]);
      _addLists(excel, await _levels());
      return ExcelWorkbook.encode(excel, _attendanceSheet);
    });
  }

  Future<Either<Failure, List<int>>> attendanceExport(AttendanceFilter filter) {
    return handleLocal(() async {
      final records = (await _attendance.records(filter)).fold((f) => throw f, (data) => data);
      final summary = (await _attendance.summary(filter)).fold((f) => throw f, (data) => data);
      final calendar = await _calendar.calendar();
      final excel = ExcelWorkbook.create();
      final ordered = records.reversed.toList();

      // Same columns as the template, so an export can be edited and imported again.
      ExcelWorkbook.addTable(excel, _attendanceSheet, attendanceColumns, [
        for (final record in ordered)
          [
            ExcelWorkbook.text(record.studentCode),
            ExcelWorkbook.text(record.studentName),
            ExcelWorkbook.text(record.levelName),
            ExcelWorkbook.text(record.gender?.label),
            TextCellValue(record.date),
            TextCellValue(record.status.label),
            ExcelWorkbook.text(record.note),
          ],
      ]);

      ExcelWorkbook.addTable(
        excel,
        _summarySheet,
        [
          const ExcelColumn('code', 'رقم الطالب', width: 14),
          const ExcelColumn('name', 'اسم الطالب', width: 32),
          const ExcelColumn('level', 'المستوى', width: 18),
          const ExcelColumn('gender', 'المجموعة', width: 12),
          for (final status in AttendanceStatus.values) ExcelColumn(status.name, status.label, width: 10),
          const ExcelColumn('total', 'أيام مسجّلة', width: 12),
          const ExcelColumn('rate', 'نسبة الحضور %', width: 14),
          const ExcelColumn('absence', 'نسبة الغياب %', width: 14),
        ],
        [
          for (final item in summary)
            [
              TextCellValue(item.code),
              TextCellValue(item.name),
              ExcelWorkbook.text(item.levelName),
              ExcelWorkbook.text(item.gender?.label),
              IntCellValue(item.present),
              IntCellValue(item.absent),
              IntCellValue(item.late),
              IntCellValue(item.excused),
              IntCellValue(item.total),
              DoubleCellValue(double.parse(item.rate.toStringAsFixed(1))),
              DoubleCellValue(double.parse(item.absenceRate.toStringAsFixed(1))),
            ],
        ],
      );

      // Students down, working days across: the classic paper register.
      final dates = {
        for (final record in ordered)
          if (calendar.isWorkingKey(record.date)) record.date,
      }.toList()..sort();
      final marks = {for (final record in records) '${record.studentId}|${record.date}': record.status.short};
      ExcelWorkbook.addTable(
        excel,
        _matrixSheet,
        [
          const ExcelColumn('code', 'رقم الطالب', width: 14),
          const ExcelColumn('name', 'اسم الطالب', width: 28),
          for (final date in dates) ExcelColumn(date, date, width: 12),
        ],
        [
          for (final item in summary)
            [
              TextCellValue(item.code),
              TextCellValue(item.name),
              for (final date in dates) ExcelWorkbook.text(marks['${item.studentId}|$date']),
            ],
        ],
      );
      ExcelWorkbook.addNotes(excel, _helpSheet, [
        'دليل الرموز في ورقة "$_matrixSheet"',
        for (final status in AttendanceStatus.values) '${status.short} = ${status.label}',
        'نسبة الحضور = (حاضر + متأخر) ÷ الأيام المسجّلة. أيام العطل وأيام عدم الدوام لا تُحسب.',
        'يمكن تعديل ورقة "$_attendanceSheet" وإعادة استيرادها مباشرة.',
      ]);
      return ExcelWorkbook.encode(excel, _attendanceSheet);
    });
  }

  Future<Either<Failure, ImportReport>> importAttendance(List<int> bytes) {
    return handleLocal(() async {
      final rows = ExcelWorkbook.read(bytes, attendanceColumns);
      final students = await _students.codeIndex();
      final calendar = await _calendar.calendar();
      if (students.isEmpty) throw const LocalFailure('Add students before importing attendance');
      final errors = <String>[];
      final seen = <String, int>{};
      final valid = <AttendanceRecord>[];
      var skipped = 0;
      for (final row in rows) {
        final code = row['code'];
        final statusText = row['status'];
        if (statusText == null) {
          skipped++;
          continue;
        }
        if (code == null) {
          errors.add('السطر ${row.number}: رقم الطالب فارغ');
          continue;
        }
        final studentId = students[code];
        if (studentId == null) {
          errors.add('السطر ${row.number}: لا يوجد طالب بالرقم ${ltr(code)} — أضفه من شاشة الطلاب أولاً');
          continue;
        }
        final date = ExcelWorkbook.dateText(row['date']);
        if (date == null) {
          errors.add(
            'السطر ${row.number}: التاريخ "${ltr(row['date'] ?? '')}" غير صالح، استخدم الشكل ${ltr('2026-10-18')}',
          );
          continue;
        }
        if (date.compareTo(dateKey(today())) > 0) {
          errors.add('السطر ${row.number}: ${ltr(date)} تاريخ في المستقبل');
          continue;
        }
        if (!calendar.isWorkingKey(date)) {
          final holiday = calendar.holidayOn(date);
          errors.add('السطر ${row.number}: ${ltr(date)} ليس يوم دوام${holiday == null ? '' : ' (${holiday.name})'}');
          continue;
        }
        final status = AttendanceStatus.parse(statusText);
        if (status == null) {
          errors.add('السطر ${row.number}: الحالة "$statusText" غير معروفة، استخدم: $_statusList');
          continue;
        }
        final key = '$code|$date';
        if (seen.containsKey(key)) {
          errors.add('السطر ${row.number}: الطالب ${ltr(code)} مكرر في تاريخ ${ltr(date)} (ورد في السطر ${seen[key]})');
          continue;
        }
        seen[key] = row.number;
        valid.add(AttendanceRecord(studentId: studentId, date: date, status: status, note: row['note']));
      }
      if (valid.isEmpty && errors.isEmpty) throw const LocalFailure('No statuses were filled in the file');
      final (added, updated) = (await _attendance.upsertMany(valid)).fold((f) => throw f, (data) => data);
      return ImportReport(added: added, updated: updated, skipped: skipped, errors: errors);
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<List<LevelModel>> _levels() async => (await _students.levels()).fold((f) => throw f, (data) => data);

  static String _identity(String name, int levelId, Gender gender) {
    return '${_collapse(name)}|$levelId|${gender.value}';
  }

  static String _collapse(String text) => text.trim().split(RegExp(r'\s+')).join(' ');

  /// Matches "المستوى الأول", "الأول", "1" (the level's position) or part of its name.
  static LevelModel? matchLevel(String? text, List<LevelModel> levels) {
    if (text == null || text.trim().isEmpty) return null;
    String clean(String value) => _collapse(value.replaceAll(RegExp('[أإآ]'), 'ا'));
    final wanted = clean(text);
    for (final level in levels) {
      if (clean(level.name) == wanted) return level;
    }
    final index = int.tryParse(wanted);
    if (index != null) return index >= 1 && index <= levels.length ? levels[index - 1] : null;
    const ordinals = ['الاول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس'];
    for (var i = 0; i < ordinals.length && i < levels.length; i++) {
      if (wanted == ordinals[i] || wanted == 'المستوى ${ordinals[i]}') return levels[i];
    }
    final partial = levels.where((level) => clean(level.name).contains(wanted)).toList();
    return partial.length == 1 ? partial.single : null;
  }

  void _addLists(Excel excel, List<LevelModel> levels) {
    ExcelWorkbook.addNotes(excel, _listsSheet, [
      'القيم المسموحة',
      'المستويات:',
      for (final level in levels) '   ${level.name}',
      'المجموعات:',
      for (final gender in Gender.values) '   ${gender.label}',
      'الحالات:',
      for (final status in AttendanceStatus.values) '   ${status.label} (${status.short})',
    ]);
  }

  static String fileName(String prefix, [String? suffix]) {
    return '${prefix}_${suffix ?? dateKey(DateTime.now())}.xlsx';
  }
}
