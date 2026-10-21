import '../../../core/utils/date_format.dart';
import '../common/json_parse.dart';

/// A holiday or break: every day from [from] to [to] (inclusive) is not a working day.
class HolidayModel {
  const HolidayModel({this.id, required this.name, required this.from, required this.to});

  final int? id;
  final String name;

  /// yyyy-MM-dd
  final String from;
  final String to;

  bool contains(String date) => date.compareTo(from) >= 0 && date.compareTo(to) <= 0;

  factory HolidayModel.fromRow(Map<String, dynamic> row) {
    return HolidayModel(
      id: asInt(row['id']),
      name: asString(row['name']) ?? '',
      from: asString(row['date_from']) ?? '',
      to: asString(row['date_to']) ?? '',
    );
  }
}

/// Which days the institute works: weekly study days minus holidays.
/// Attendance is only taken and counted on working days.
class WorkCalendar {
  const WorkCalendar({required this.weekdays, this.holidays = const []});

  /// Dart weekdays (DateTime.monday = 1 … DateTime.sunday = 7).
  final Set<int> weekdays;
  final List<HolidayModel> holidays;

  /// Saturday to Thursday.
  static const Set<int> defaultWeekdays = {
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  };

  HolidayModel? holidayOn(String date) {
    for (final holiday in holidays) {
      if (holiday.contains(date)) return holiday;
    }
    return null;
  }

  bool isWorkingDay(DateTime date) => weekdays.contains(date.weekday) && holidayOn(dateKey(date)) == null;

  bool isWorkingKey(String date) {
    final parsed = parseDate(date);
    return parsed != null && isWorkingDay(parsed);
  }

  /// Number of working days between two dates, both included.
  int workingDaysBetween(DateTime from, DateTime to) {
    var count = 0;
    for (var day = from; !day.isAfter(to); day = DateTime(day.year, day.month, day.day + 1)) {
      if (isWorkingDay(day)) count++;
    }
    return count;
  }

  /// SQLite strftime('%w') numbers: Sunday = 0 … Saturday = 6.
  List<int> get sqliteWeekdays => [for (final day in weekdays) day % 7];
}
