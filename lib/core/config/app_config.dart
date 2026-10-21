/// Environment values for the whole app. Everything runs on the device; there is no server.
abstract final class AppConfig {
  static const String appName = 'معهد الإمام الشافعي';
  static const String appSubtitle = 'للعلوم الشرعية';

  static const String databaseName = 'attendance.db';
  static const int databaseVersion = 3;

  /// Dates are stored and exchanged in Excel as yyyy-MM-dd.
  static const String dateFormat = 'yyyy-MM-dd';

  /// Student numbers are given automatically, counting up from here.
  static const int firstStudentNumber = 1001;

  /// Levels created on first launch. They can be renamed or extended in the settings.
  static const List<String> defaultLevels = ['المستوى الأول', 'المستوى الثاني', 'المستوى الثالث'];
}
