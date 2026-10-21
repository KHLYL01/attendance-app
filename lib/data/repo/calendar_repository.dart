import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/handle_local_request.dart';
import '../local/app_database.dart';
import '../local/failures.dart';
import '../model/calendar/calendar_models.dart';

/// Study weekdays and holidays: the days attendance is taken and counted.
class CalendarRepository {
  CalendarRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const _h = AppDatabase.holidays;

  Future<WorkCalendar> calendar() async {
    final setting = await _db.query(AppDatabase.settings, where: 'key = ?', whereArgs: [AppDatabase.weekdaysKey]);
    final text = setting.isEmpty ? null : setting.first['value'] as String?;
    final weekdays = text == null
        ? WorkCalendar.defaultWeekdays
        : text.split(',').map(int.tryParse).whereType<int>().toSet();
    final holidays = await _db.query(_h, orderBy: 'date_from DESC');
    return WorkCalendar(weekdays: weekdays, holidays: holidays.map(HolidayModel.fromRow).toList());
  }

  Future<Either<Failure, WorkCalendar>> load() => handleLocal(calendar);

  Future<Either<Failure, void>> saveWeekdays(Set<int> weekdays) {
    return handleLocal(() async {
      if (weekdays.isEmpty) throw const LocalFailure('Choose at least one study day');
      await _db.insert(AppDatabase.settings, {
        'key': AppDatabase.weekdaysKey,
        'value': (weekdays.toList()..sort()).join(','),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<Either<Failure, void>> saveHoliday(HolidayModel holiday) {
    return handleLocal(() async {
      final from = holiday.from.compareTo(holiday.to) <= 0 ? holiday.from : holiday.to;
      final to = holiday.from.compareTo(holiday.to) <= 0 ? holiday.to : holiday.from;
      final row = {'name': holiday.name.trim(), 'date_from': from, 'date_to': to};
      if (holiday.id == null) {
        await _db.insert(_h, row);
      } else {
        await _db.update(_h, row, where: 'id = ?', whereArgs: [holiday.id]);
      }
    });
  }

  Future<Either<Failure, void>> deleteHoliday(int id) {
    return handleLocal(() => _db.delete(_h, where: 'id = ?', whereArgs: [id]));
  }

  /// SQL that keeps only rows whose [column] (yyyy-MM-dd) falls on a working day.
  static String workingDaySql(String column, WorkCalendar calendar) {
    final days = calendar.sqliteWeekdays;
    return "CAST(strftime('%w', $column) AS INTEGER) IN (${days.isEmpty ? '-1' : days.join(',')}) "
        'AND NOT EXISTS (SELECT 1 FROM $_h h WHERE $column BETWEEN h.date_from AND h.date_to)';
  }
}
