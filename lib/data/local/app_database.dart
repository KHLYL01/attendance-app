import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/date_format.dart';
import '../model/calendar/calendar_models.dart';

/// The single on-device SQLite database. Students and attendance records live in separate tables.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const String students = 'students';
  static const String attendance = 'attendance';
  static const String levels = 'levels';
  static const String holidays = 'holidays';
  static const String settings = 'settings';

  /// settings key holding the study weekdays, e.g. "6,7,1,2,3,4".
  static const String weekdaysKey = 'weekdays';

  static bool _ffiReady = false;

  static Future<AppDatabase> open({String? path}) async {
    if ((Platform.isWindows || Platform.isLinux) && !_ffiReady) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiReady = true;
    }
    final location = path ?? p.join(await getDatabasesPath(), AppConfig.databaseName);
    final db = await openDatabase(
      location,
      version: AppConfig.databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _create(db),
      onUpgrade: _upgrade,
    );
    return AppDatabase(db);
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch();
    _createLevels(batch);
    batch.execute('''
      CREATE TABLE $students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        level_id INTEGER NOT NULL REFERENCES $levels(id),
        gender TEXT NOT NULL,
        level_since TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE $attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES $students(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        note TEXT,
        updated_at TEXT NOT NULL,
        UNIQUE(student_id, date)
      )
    ''');
    batch.execute('CREATE INDEX idx_attendance_date ON $attendance(date)');
    _createCalendar(batch);
    _createGroupIndex(batch);
    await batch.commit(noResult: true);
  }

  /// Version 1 had a free-text group, phone and notes. Old columns are left in place (unused)
  /// so that no attendance record is touched; every student starts in the first level.
  static Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      final batch = db.batch();
      _createLevels(batch);
      batch.execute('ALTER TABLE $students ADD COLUMN level_id INTEGER REFERENCES $levels(id)');
      batch.execute("ALTER TABLE $students ADD COLUMN gender TEXT NOT NULL DEFAULT 'MALE'");
      batch.execute('ALTER TABLE $students ADD COLUMN level_since TEXT');
      batch.execute(
        'UPDATE $students SET level_id = (SELECT MIN(id) FROM $levels), level_since = substr(created_at, 1, 10)',
      );
      _createCalendar(batch);
      _createGroupIndex(batch);
      await batch.commit(noResult: true);
    }
    if (from < 3) {
      // level_since now means "moved to this level on"; empty means never moved, and the
      // current-level period then starts at the student's first record.
      await db.execute("UPDATE $students SET level_since = ''");
    }
  }

  static void _createLevels(Batch batch) {
    batch.execute('''
      CREATE TABLE $levels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL
      )
    ''');
    for (var i = 0; i < AppConfig.defaultLevels.length; i++) {
      batch.insert(levels, {'name': AppConfig.defaultLevels[i], 'sort_order': i + 1});
    }
  }

  static void _createCalendar(Batch batch) {
    batch.execute('''
      CREATE TABLE $holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date_from TEXT NOT NULL,
        date_to TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE TABLE $settings (key TEXT PRIMARY KEY, value TEXT)');
    batch.insert(settings, {'key': weekdaysKey, 'value': WorkCalendar.defaultWeekdays.join(',')});
  }

  static void _createGroupIndex(Batch batch) {
    batch.execute('CREATE INDEX idx_students_level ON $students(level_id, gender)');
  }

  /// Today, as stored in level_since when a student moves to another level.
  static String todayKey() => dateKey(today());

  Future<void> close() => db.close();
}
