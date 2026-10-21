import 'package:intl/intl.dart';

import '../config/app_config.dart';

final _storage = DateFormat(AppConfig.dateFormat);

/// The yyyy-MM-dd key used in the database and in Excel files.
String dateKey(DateTime date) => _storage.format(date);

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Reads a date typed by a person: yyyy-MM-dd, yyyy/MM/dd, dd/MM/yyyy or dd-MM-yyyy.
DateTime? parseDate(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
  if (iso != null) {
    return _valid(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  }
  final dayFirst = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(text);
  if (dayFirst != null) {
    return _valid(int.parse(dayFirst[3]!), int.parse(dayFirst[2]!), int.parse(dayFirst[1]!));
  }
  return null;
}

DateTime? _valid(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// A long Arabic label such as "السبت 18 أكتوبر 2026".
String displayDate(String key) {
  final date = parseDate(key);
  if (date == null) return key;
  return _latinDigits(DateFormat('EEEE d MMMM yyyy', 'ar').format(date));
}

/// Keeps digits the same as everywhere else in the app (and in Excel): 0-9.
String _latinDigits(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return text.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${arabic.indexOf(m[0]!)}');
}

/// Keeps a date or code reading left to right inside an Arabic sentence, so
/// "2026-10-20" is not shown as "20-10-2026".
String ltr(String text) => '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';
