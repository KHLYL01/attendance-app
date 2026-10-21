import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/handle_local_request.dart';
import '../local/app_database.dart';
import '../local/failures.dart';
import '../model/student/student_model.dart';

class StudentRepository {
  StudentRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const _s = AppDatabase.students;
  static const _l = AppDatabase.levels;

  // ─── Students ─────────────────────────────────────────────────────────────

  Future<Either<Failure, List<StudentModel>>> students({GroupFilter group = const GroupFilter()}) {
    return handleLocal(() async {
      final (where, args) = group.sql('s');
      final rows = await _db.rawQuery(
        'SELECT s.*, l.name AS level_name FROM $_s s LEFT JOIN $_l l ON l.id = s.level_id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY l.sort_order, s.gender DESC, s.name COLLATE NOCASE',
        args,
      );
      return rows.map(StudentModel.fromRow).toList();
    });
  }

  Future<Either<Failure, StudentModel>> student(int id) {
    return handleLocal(() async {
      final rows = await _db.rawQuery(
        'SELECT s.*, l.name AS level_name FROM $_s s LEFT JOIN $_l l ON l.id = s.level_id WHERE s.id = ?',
        [id],
      );
      if (rows.isEmpty) throw const LocalFailure('Student not found');
      return StudentModel.fromRow(rows.first);
    });
  }

  /// New students get the next free number. Moving a student to another level restarts
  /// their "current level" period from today.
  Future<Either<Failure, StudentModel>> save(StudentModel student) {
    return handleLocal(() async {
      final row = {'name': student.name.trim(), 'level_id': student.levelId, 'gender': student.gender.value};
      if (student.id == null) {
        final code = await nextCode();
        final id = await _db.insert(_s, {
          ...row,
          'code': code,
          'level_since': '',
          'created_at': DateTime.now().toIso8601String(),
        });
        return student.copyWith(id: id, code: code);
      }
      final current = await _db.query(_s, columns: ['level_id'], where: 'id = ?', whereArgs: [student.id]);
      final moved = current.isNotEmpty && current.first['level_id'] != student.levelId;
      await _db.update(
        _s,
        {...row, if (moved) 'level_since': AppDatabase.todayKey()},
        where: 'id = ?',
        whereArgs: [student.id],
      );
      return student;
    });
  }

  /// Deletes the student and, through the foreign key, all of their attendance records.
  Future<Either<Failure, void>> delete(int id) {
    return handleLocal(() => _db.delete(_s, where: 'id = ?', whereArgs: [id]));
  }

  /// Rows with an existing number update that student; rows without a number are added
  /// with new numbers, in file order. Returns (added, updated).
  Future<Either<Failure, (int, int)>> upsertMany(List<StudentModel> students) {
    return handleLocal(() async {
      final existing = await _db.query(_s, columns: ['id', 'code', 'level_id']);
      final byCode = {for (final row in existing) row['code'] as String: row};
      var next = int.parse(await nextCode());
      var added = 0;
      var updated = 0;
      await _db.transaction((txn) async {
        final batch = txn.batch();
        final now = DateTime.now().toIso8601String();
        final since = AppDatabase.todayKey();
        for (final student in students) {
          final row = {'name': student.name.trim(), 'level_id': student.levelId, 'gender': student.gender.value};
          final current = byCode[student.code.trim()];
          if (current == null) {
            batch.insert(_s, {...row, 'code': '${next++}', 'level_since': '', 'created_at': now});
            added++;
          } else {
            final moved = current['level_id'] != student.levelId;
            batch.update(_s, {...row, if (moved) 'level_since': since}, where: 'id = ?', whereArgs: [current['id']]);
            updated++;
          }
        }
        await batch.commit(noResult: true);
      });
      return (added, updated);
    });
  }

  /// Student number → id, used to link imported attendance rows.
  Future<Map<String, int>> codeIndex() async {
    final rows = await _db.query(_s, columns: ['id', 'code']);
    return {for (final row in rows) row['code'] as String: row['id'] as int};
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS total FROM $_s');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// One more than the highest number in use, never below [AppConfig.firstStudentNumber].
  Future<String> nextCode() async {
    final rows = await _db.rawQuery("SELECT MAX(CAST(code AS INTEGER)) AS top FROM $_s WHERE code GLOB '[0-9]*'");
    final top = Sqflite.firstIntValue(rows) ?? 0;
    return '${top < AppConfig.firstStudentNumber ? AppConfig.firstStudentNumber : top + 1}';
  }

  // ─── Levels ───────────────────────────────────────────────────────────────

  Future<Either<Failure, List<LevelModel>>> levels() {
    return handleLocal(() async {
      final rows = await _db.rawQuery(
        "SELECT l.*, COUNT(s.id) AS student_count, SUM(CASE WHEN s.gender = 'FEMALE' THEN 1 ELSE 0 END) AS female_count "
        'FROM $_l l '
        'LEFT JOIN $_s s ON s.level_id = l.id GROUP BY l.id ORDER BY l.sort_order, l.id',
      );
      return rows.map(LevelModel.fromRow).toList();
    });
  }

  Future<Either<Failure, void>> saveLevel({int? id, required String name}) {
    return handleLocal(() async {
      final clash = await _db.query(
        _l,
        columns: ['id'],
        where: id == null ? 'name = ?' : 'name = ? AND id != ?',
        whereArgs: id == null ? [name.trim()] : [name.trim(), id],
      );
      if (clash.isNotEmpty) throw const LocalFailure('Level name already exists');
      if (id == null) {
        final rows = await _db.rawQuery('SELECT MAX(sort_order) AS top FROM $_l');
        await _db.insert(_l, {'name': name.trim(), 'sort_order': (Sqflite.firstIntValue(rows) ?? 0) + 1});
      } else {
        await _db.update(_l, {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<Either<Failure, void>> deleteLevel(int id) {
    return handleLocal(() async {
      final used = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $_s WHERE level_id = ?', [id]));
      if ((used ?? 0) > 0) throw const LocalFailure('Move the students out of this level first');
      await _db.delete(_l, where: 'id = ?', whereArgs: [id]);
    });
  }
}
