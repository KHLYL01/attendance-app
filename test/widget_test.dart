import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:attendence_app/core/utils/date_format.dart';

import 'package:attendence_app/data/local/app_database.dart';
import 'package:attendence_app/data/model/attendance/attendance_models.dart';
import 'package:attendence_app/data/model/calendar/calendar_models.dart';
import 'package:attendence_app/data/model/student/student_model.dart';
import 'package:attendence_app/data/repo/attendance_repository.dart';
import 'package:attendence_app/data/repo/calendar_repository.dart';
import 'package:attendence_app/data/repo/excel_repository.dart';
import 'package:attendence_app/data/repo/student_repository.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

T _right<T>(dynamic either) => either.fold((f) => fail('Expected success, got ${f.message}'), (value) => value);

// 2026-10-18 is a Sunday, 2026-10-19 a Monday and 2026-10-23 a Friday (not a study day by default).
const _sunday = '2026-10-18';
const _monday = '2026-10-19';
const _friday = '2026-10-23';

void main() {
  late AppDatabase database;
  late StudentRepository students;
  late CalendarRepository calendar;
  late AttendanceRepository attendance;
  late ExcelRepository excel;
  late List<LevelModel> levels;

  StudentModel student(String name, {int level = 0, Gender gender = Gender.male}) {
    return StudentModel(name: name, levelId: levels[level].id!, gender: gender);
  }

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    students = StudentRepository(database);
    calendar = CalendarRepository(database);
    attendance = AttendanceRepository(database, calendar);
    excel = ExcelRepository(students, attendance, calendar);
    levels = _right(await students.levels());
  });

  tearDown(() => database.close());

  test('three levels exist on first launch', () {
    expect(levels.map((level) => level.name), ['المستوى الأول', 'المستوى الثاني', 'المستوى الثالث']);
  });

  test('students get unique numbers automatically', () async {
    final first = _right<StudentModel>(await students.save(student('أحمد')));
    final second = _right<StudentModel>(await students.save(student('سارة', gender: Gender.female)));
    expect(first.code, '1001');
    expect(second.code, '1002');

    // Numbers keep counting up after a delete.
    _right(await students.delete(first.id!));
    final third = _right<StudentModel>(await students.save(student('ليلى', gender: Gender.female)));
    expect(third.code, '1003');
  });

  test('moving a student to another level restarts the level period', () async {
    final ahmad = _right<StudentModel>(await students.save(student('أحمد')));
    await database.db.update(
      AppDatabase.students,
      {'level_since': '2025-01-01'},
      where: 'id = ?',
      whereArgs: [ahmad.id],
    );

    _right(
      await students.save(StudentModel(id: ahmad.id, name: 'أحمد علي', levelId: levels[0].id!, gender: Gender.male)),
    );
    expect(_right<StudentModel>(await students.student(ahmad.id!)).levelSince, '2025-01-01');

    _right(
      await students.save(StudentModel(id: ahmad.id, name: 'أحمد علي', levelId: levels[1].id!, gender: Gender.male)),
    );
    final moved = _right<StudentModel>(await students.student(ahmad.id!));
    expect(moved.levelSince, AppDatabase.todayKey());
    expect(moved.levelName, 'المستوى الثاني');
  });

  test('a level with students cannot be deleted', () async {
    _right(await students.save(student('أحمد')));
    expect((await students.deleteLevel(levels[0].id!)).isLeft(), isTrue);
    expect((await students.deleteLevel(levels[2].id!)).isRight(), isTrue);
  });

  test('attendance is refused on days off and not counted there', () async {
    final ahmad = _right<StudentModel>(await students.save(student('أحمد')));
    final present = {ahmad.id!: const AttendanceEntry(AttendanceStatus.present)};
    final absent = {ahmad.id!: const AttendanceEntry(AttendanceStatus.absent)};

    expect((await attendance.saveDay(_friday, present)).isLeft(), isTrue);
    _right(await attendance.saveDay(_sunday, present));
    _right(await attendance.saveDay(_monday, absent));

    var summary = _right<List<AttendanceSummary>>(await attendance.summary(const AttendanceFilter())).single;
    expect(summary.total, 2);
    expect(summary.rate, 50);
    expect(summary.absenceRate, 50);

    // Declaring Monday a holiday drops its record from the totals.
    _right(await calendar.saveHoliday(const HolidayModel(name: 'عطلة', from: _monday, to: _monday)));
    summary = _right<List<AttendanceSummary>>(await attendance.summary(const AttendanceFilter())).single;
    expect(summary.total, 1);
    expect(summary.rate, 100);

    final work = await calendar.calendar();
    expect(work.isWorkingKey(_monday), isFalse);
    // Sunday 18 → Saturday 24 October: Sunday, Tuesday, Wednesday, Thursday, Saturday.
    expect(work.workingDaysBetween(DateTime(2026, 10, 18), DateTime(2026, 10, 24)), 5);
  });

  test('students template: numbers are given on import, known numbers update', () async {
    final existing = _right<StudentModel>(await students.save(student('قديم')));

    final template = Excel.decodeBytes(_right<List<int>>(await excel.studentsTemplate()));
    final sheet = template['الطلاب'];
    sheet.appendRow([null, TextCellValue('أحمد علي'), TextCellValue('المستوى الأول'), TextCellValue('ذكور')]);
    sheet.appendRow([null, TextCellValue('سارة'), TextCellValue('الثاني'), TextCellValue('إناث')]);
    sheet.appendRow([null, TextCellValue('ليلى'), IntCellValue(3), TextCellValue('بنات')]);
    sheet.appendRow([
      TextCellValue(existing.code),
      TextCellValue('قديم معدل'),
      TextCellValue('2'),
      TextCellValue('ذكور'),
    ]);
    sheet.appendRow([null, TextCellValue('أحمد علي'), TextCellValue('المستوى الأول'), TextCellValue('ذكور')]);
    sheet.appendRow([null, TextCellValue('بلا مستوى'), TextCellValue('العاشر'), TextCellValue('ذكور')]);
    sheet.appendRow([TextCellValue('9999'), TextCellValue('رقم غريب'), TextCellValue('1'), TextCellValue('ذكور')]);

    final report = _right(await excel.importStudents(template.encode()!));
    expect(report.added, 3);
    expect(report.updated, 1);
    expect(report.errors.length, 3);

    final all = _right<List<StudentModel>>(await students.students());
    expect(all.map((item) => item.code).toSet(), {'1001', '1002', '1003', '1004'});
    final sara = all.firstWhere((item) => item.name == 'سارة');
    expect(sara.levelId, levels[1].id);
    expect(sara.gender, Gender.female);
    expect(all.firstWhere((item) => item.code == existing.code).name, 'قديم معدل');

    // Importing the same file again adds nobody.
    final again = _right(await excel.importStudents(template.encode()!));
    expect(again.added, 0);
  });

  test('attendance template is prefilled, skips days off and imports by number', () async {
    final ahmad = _right<StudentModel>(await students.save(student('أحمد')));
    final sara = _right<StudentModel>(await students.save(student('سارة', gender: Gender.female)));
    final layla = _right<StudentModel>(await students.save(student('ليلى', level: 1, gender: Gender.female)));

    expect((await excel.attendanceTemplate(date: _friday)).isLeft(), isTrue);

    final girls = Excel.decodeBytes(
      _right<List<int>>(
        await excel.attendanceTemplate(
          date: _sunday,
          group: const GroupFilter(gender: Gender.female),
        ),
      ),
    );
    expect(girls['الحضور'].maxRows, 3);

    final template = Excel.decodeBytes(_right<List<int>>(await excel.attendanceTemplate(date: _sunday)));
    final sheet = template['الحضور'];
    for (var row = 1; row < sheet.maxRows; row++) {
      final code = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value.toString();
      final status = code == ahmad.code ? 'حاضر' : (code == sara.code ? 'غ' : null);
      if (status != null) {
        sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row), TextCellValue(status));
      }
    }
    sheet.appendRow([TextCellValue('9999'), null, null, null, TextCellValue(_sunday), TextCellValue('حاضر'), null]);
    sheet.appendRow([TextCellValue(layla.code), null, null, null, TextCellValue(_friday), TextCellValue('حاضر'), null]);
    sheet.appendRow([
      TextCellValue(layla.code),
      null,
      null,
      null,
      const DateCellValue(year: 2026, month: 10, day: 19),
      TextCellValue('متأخر'),
      null,
    ]);

    final report = _right(await excel.importAttendance(template.encode()!));
    expect(report.added, 3);
    expect(report.skipped, 1);
    expect(report.errors.length, 2);

    final records = _right<List<AttendanceRecord>>(await attendance.records(const AttendanceFilter()));
    final byKey = {for (final record in records) '${record.studentCode}|${record.date}': record.status};
    expect(byKey['${ahmad.code}|$_sunday'], AttendanceStatus.present);
    expect(byKey['${sara.code}|$_sunday'], AttendanceStatus.absent);
    expect(byKey['${layla.code}|$_monday'], AttendanceStatus.late);

    // The export's first sheet uses the template's columns, so it can be imported again.
    final exported = _right<List<int>>(await excel.attendanceExport(const AttendanceFilter()));
    final again = _right(await excel.importAttendance(exported));
    expect(again.updated, 3);
    expect(again.errors, isEmpty);
  });

  test('new students have no level date; the period starts at their first record', () async {
    final ahmad = _right<StudentModel>(await students.save(student('أحمد')));
    expect(_right<StudentModel>(await students.student(ahmad.id!)).levelSince, isNull);
    expect(await attendance.firstDate(ahmad.id!), isNull);
    _right(await attendance.saveDay(_monday, {ahmad.id!: const AttendanceEntry(AttendanceStatus.present)}));
    _right(await attendance.saveDay(_sunday, {ahmad.id!: const AttendanceEntry(AttendanceStatus.present)}));
    expect(await attendance.firstDate(ahmad.id!), _sunday);
  });

  test('attendance for a future day is refused', () async {
    final ahmad = _right<StudentModel>(await students.save(student('أحمد')));
    _right(await calendar.saveWeekdays({1, 2, 3, 4, 5, 6, 7}));
    final tomorrow = dateKey(today().add(const Duration(days: 1)));
    final saved = await attendance.saveDay(tomorrow, {ahmad.id!: const AttendanceEntry(AttendanceStatus.present)});
    expect(saved.isLeft(), isTrue);
  });

  test('every sheet of an exported file reads right to left', () async {
    _right(await students.save(student('أحمد')));
    final bytes = _right<List<int>>(await excel.attendanceExport(const AttendanceFilter()));
    final sheets = ZipDecoder().decodeBytes(bytes).files.where((f) => f.name.startsWith('xl/worksheets/sheet'));
    expect(sheets, isNotEmpty);
    for (final sheet in sheets) {
      expect(utf8.decode(sheet.content as List<int>), contains('rightToLeft="1"'), reason: sheet.name);
    }
    // And the file still opens.
    expect(Excel.decodeBytes(bytes).tables.keys, contains('الحضور'));
  });

  test('files whose sheets are linked with absolute paths can be imported', () async {
    final template = Excel.decodeBytes(_right<List<int>>(await excel.studentsTemplate()));
    template['الطلاب'].appendRow([null, TextCellValue('أحمد'), TextCellValue('1'), TextCellValue('ذكور')]);
    // Rewrite the sheet links the way openpyxl and LibreOffice write them.
    final source = ZipDecoder().decodeBytes(template.encode()!);
    final output = Archive();
    for (final file in source.files) {
      if (file.name == 'xl/_rels/workbook.xml.rels') {
        final xml = utf8.decode(file.content as List<int>).replaceAll('Target="worksheets/', 'Target="/xl/worksheets/');
        final content = utf8.encode(xml);
        output.addFile(ArchiveFile(file.name, content.length, content));
      } else {
        output.addFile(file);
      }
    }
    final report = _right(await excel.importStudents(ZipEncoder().encode(output)!));
    expect(report.added, 1);
  });

  test('deleting a student removes their records', () async {
    final ahmad = _right<StudentModel>(await students.save(student('أحمد')));
    _right(await attendance.saveDay(_sunday, {ahmad.id!: const AttendanceEntry(AttendanceStatus.present)}));
    _right(await students.delete(ahmad.id!));
    final records = _right<List<AttendanceRecord>>(await attendance.records(const AttendanceFilter()));
    expect(records, isEmpty);
  });

  test('version 1 databases are upgraded without losing records', () async {
    final folder = Directory.systemTemp.createTempSync('attendance_v1_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final path = '${folder.path}/attendance.db';
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE students (id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, '
            'name TEXT NOT NULL, group_name TEXT, phone TEXT, notes TEXT, created_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE attendance (id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL '
            'REFERENCES students(id) ON DELETE CASCADE, date TEXT NOT NULL, status TEXT NOT NULL, note TEXT, '
            'updated_at TEXT NOT NULL, UNIQUE(student_id, date))',
          );
          await db.execute('CREATE INDEX idx_students_group ON students(group_name)');
          await db.insert('students', {'code': '7', 'name': 'قديم', 'created_at': '2026-09-01T10:00:00'});
          await db.insert('attendance', {'student_id': 1, 'date': _sunday, 'status': 'PRESENT', 'updated_at': 'x'});
        },
      ),
    );
    await old.close();
    final upgraded = await AppDatabase.open(path: path);
    final repo = StudentRepository(upgraded);
    final migrated = _right<List<StudentModel>>(await repo.students()).single;
    expect(migrated.levelName, 'المستوى الأول');
    // Never moved: the current-level period starts at the first record.
    expect(migrated.levelSince, isNull);
    expect(await repo.nextCode(), '1001');
    final rows = await upgraded.db.query(AppDatabase.attendance);
    expect(rows, hasLength(1));
    await upgraded.close();
  });
}
