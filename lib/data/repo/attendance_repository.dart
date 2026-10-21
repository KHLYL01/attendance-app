import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_format.dart';
import '../../core/utils/handle_local_request.dart';
import '../local/app_database.dart';
import '../local/failures.dart';
import '../model/attendance/attendance_models.dart';
import 'calendar_repository.dart';

class AttendanceRepository {
  AttendanceRepository(this._database, this._calendar);

  final AppDatabase _database;
  final CalendarRepository _calendar;

  Database get _db => _database.db;

  static const _a = AppDatabase.attendance;
  static const _s = AppDatabase.students;
  static const _l = AppDatabase.levels;

  /// Student id → record for one day.
  Future<Either<Failure, Map<int, AttendanceRecord>>> day(String date) {
    return handleLocal(() async {
      final rows = await _db.query(_a, where: 'date = ?', whereArgs: [date]);
      final records = rows.map(AttendanceRecord.fromRow);
      return {for (final record in records) record.studentId: record};
    });
  }

  /// Writes one day for the given students. Entries with a null status remove the record.
  Future<Either<Failure, void>> saveDay(String date, Map<int, AttendanceEntry> entries) {
    return handleLocal(() async {
      final calendar = await _calendar.calendar();
      if (!calendar.isWorkingKey(date)) throw const LocalFailure('This day is not a study day');
      if (date.compareTo(dateKey(today())) > 0) throw const LocalFailure('Attendance cannot be taken for a future day');
      await _db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().toIso8601String();
        entries.forEach((studentId, entry) {
          if (entry.status == null) {
            batch.delete(_a, where: 'student_id = ? AND date = ?', whereArgs: [studentId, date]);
          } else {
            batch.insert(_a, {
              'student_id': studentId,
              'date': date,
              'status': entry.status!.value,
              'note': _blank(entry.note),
              'updated_at': now,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
        await batch.commit(noResult: true);
      });
    });
  }

  /// Every matching record, including any left on a day later declared a holiday,
  /// so they can still be seen and deleted.
  Future<Either<Failure, List<AttendanceRecord>>> records(AttendanceFilter filter) {
    return handleLocal(() async {
      final (where, args) = _where(filter);
      final rows = await _db.rawQuery(
        'SELECT a.*, s.code, s.name, s.gender, l.name AS level_name FROM $_a a '
        'JOIN $_s s ON s.id = a.student_id LEFT JOIN $_l l ON l.id = s.level_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY a.date DESC, l.sort_order, s.gender DESC, s.name COLLATE NOCASE',
        args,
      );
      return rows.map(AttendanceRecord.fromRow).toList();
    });
  }

  Future<Either<Failure, void>> update(AttendanceRecord record) {
    return handleLocal(() async {
      await _db.update(
        _a,
        {'status': record.status.value, 'note': _blank(record.note), 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [record.id],
      );
    });
  }

  Future<Either<Failure, void>> delete(int id) {
    return handleLocal(() => _db.delete(_a, where: 'id = ?', whereArgs: [id]));
  }

  /// Every student with their totals, counting working days only. Students with no
  /// records in the period appear with zeros.
  Future<Either<Failure, List<AttendanceSummary>>> summary(AttendanceFilter filter) {
    return handleLocal(() async {
      final calendar = await _calendar.calendar();
      final join = <String>['a.student_id = s.id', CalendarRepository.workingDaySql('a.date', calendar)];
      final args = <Object?>[];
      if (filter.from != null) {
        join.add('a.date >= ?');
        args.add(filter.from);
      }
      if (filter.to != null) {
        join.add('a.date <= ?');
        args.add(filter.to);
      }
      final (where, groupArgs) = filter.group.sql('s');
      args.addAll(groupArgs);
      if (filter.studentId != null) {
        where.add('s.id = ?');
        args.add(filter.studentId);
      }
      String count(AttendanceStatus status) =>
          "SUM(CASE WHEN a.status = '${status.value}' THEN 1 ELSE 0 END) AS ${status.name}";
      final rows = await _db.rawQuery(
        'SELECT s.id, s.code, s.name, s.gender, l.name AS level_name, '
        '${AttendanceStatus.values.map(count).join(', ')} '
        'FROM $_s s LEFT JOIN $_l l ON l.id = s.level_id '
        'LEFT JOIN $_a a ON ${join.join(' AND ')} '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'GROUP BY s.id ORDER BY l.sort_order, s.gender DESC, s.name COLLATE NOCASE',
        args,
      );
      return rows.map(AttendanceSummary.fromRow).toList();
    });
  }

  /// The student's earliest record, as yyyy-MM-dd, or null when they have none.
  Future<String?> firstDate(int studentId) async {
    final rows = await _db.rawQuery('SELECT MIN(date) AS first FROM $_a WHERE student_id = ?', [studentId]);
    return rows.first['first'] as String?;
  }

  Future<Either<Failure, DayCounts>> dayCounts(String date) {
    return handleLocal(() async {
      final rows = await _db.rawQuery('SELECT status, COUNT(*) AS total FROM $_a WHERE date = ? GROUP BY status', [
        date,
      ]);
      return DayCounts({
        for (final row in rows)
          if (AttendanceStatus.fromValue(row['status'] as String?) case final status?) status: row['total'] as int,
      });
    });
  }

  /// Inserts or replaces rows by (student, date) in one transaction. Returns (added, updated).
  Future<Either<Failure, (int, int)>> upsertMany(List<AttendanceRecord> records) {
    return handleLocal(() async {
      if (records.isEmpty) return (0, 0);
      final existing = await _db.query(_a, columns: ['student_id', 'date']);
      final keys = {for (final row in existing) '${row['student_id']}|${row['date']}'};
      var added = 0;
      var updated = 0;
      await _db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().toIso8601String();
        for (final record in records) {
          keys.contains('${record.studentId}|${record.date}') ? updated++ : added++;
          batch.insert(_a, {
            'student_id': record.studentId,
            'date': record.date,
            'status': record.status.value,
            'note': _blank(record.note),
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
      return (added, updated);
    });
  }

  (List<String>, List<Object?>) _where(AttendanceFilter filter) {
    final (parts, args) = filter.group.sql('s');
    if (filter.from != null) {
      parts.add('a.date >= ?');
      args.add(filter.from);
    }
    if (filter.to != null) {
      parts.add('a.date <= ?');
      args.add(filter.to);
    }
    if (filter.status != null) {
      parts.add('a.status = ?');
      args.add(filter.status!.value);
    }
    if (filter.studentId != null) {
      parts.add('a.student_id = ?');
      args.add(filter.studentId);
    }
    return (parts, args);
  }

  static String? _blank(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
