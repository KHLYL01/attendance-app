import 'package:attendence_app/core/localization/translation.dart';
import 'package:attendence_app/core/routes/app_pages.dart';
import 'package:attendence_app/core/routes/app_routes.dart';
import 'package:attendence_app/core/theme/app_theme.dart';
import 'package:attendence_app/core/utils/date_format.dart';
import 'package:attendence_app/data/local/app_database.dart';
import 'package:attendence_app/data/model/attendance/attendance_models.dart';
import 'package:attendence_app/data/model/student/student_model.dart';
import 'package:attendence_app/core/di/di.dart';
import 'package:attendence_app/data/repo/attendance_repository.dart';
import 'package:attendence_app/data/repo/calendar_repository.dart';
import 'package:attendence_app/data/repo/student_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Lets the SQLite isolate answer: each round trip needs real time and then a frame.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Widget _app() {
  return GetMaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar')],
    locale: const Locale('ar'),
    translations: MyTranslation(),
    theme: AppTheme.light,
    initialRoute: AppRoutes.home,
    getPages: AppPages.pages,
  );
}

void main() {
  late AppDatabase database;

  setUp(() async {
    await initializeDateFormatting('ar');
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    registerRepositories(database);
    final students = Get.find<StudentRepository>();
    final attendance = Get.find<AttendanceRepository>();
    // Every weekday is a study day here so the test does not depend on what day it runs.
    await Get.find<CalendarRepository>().saveWeekdays({1, 2, 3, 4, 5, 6, 7});
    final levels = (await students.levels()).fold((_) => <LevelModel>[], (items) => items);
    for (var i = 1; i <= 6; i++) {
      await students.save(
        StudentModel(name: 'طالب رقم $i', levelId: levels[i % 3].id!, gender: i.isEven ? Gender.male : Gender.female),
      );
    }
    final ids = (await students.codeIndex()).values;
    await attendance.saveDay(dateKey(today()), {
      for (final id in ids) id: AttendanceEntry(id.isEven ? AttendanceStatus.present : AttendanceStatus.absent),
    });
  });

  tearDown(() async {
    Get.reset();
    await database.close();
  });

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('every section renders at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await _settle(tester);
      expect(find.text('الصفحة الرئيسية'), findsWidgets);

      for (final label in ['الطلاب', 'تسجيل الحضور', 'السجلات']) {
        await tester.tap(find.text(label).last);
        await _settle(tester);
        expect(find.textContaining('طالب رقم'), findsWidgets, reason: label);
      }

      // A student's page shows their rates.
      await tester.tap(find.text('الطلاب').last);
      await _settle(tester);
      await tester.tap(find.textContaining('طالب رقم').first);
      await _settle(tester);
      expect(find.text('نسبة الحضور'), findsOneWidget);
      expect(find.text('نسبة الغياب'), findsOneWidget);
      await tester.tap(find.text('المستوى الحالي'));
      await _settle(tester);
      // Editing opens from the student's page (on phones this is a second pushed page).
      await tester.tap(find.text('تعديل'));
      await _settle(tester);
      expect(find.text('حفظ الطالب'), findsOneWidget);
      if (size.width < 900) {
        Get.back<void>();
        await _settle(tester);
        Get.back<void>();
        await _settle(tester);
      }

      // Settings open from the top bar.
      await tester.tap(find.byTooltip('الإعدادات'));
      await _settle(tester);
      expect(find.text('أيام الدوام'), findsOneWidget);
      Get.back<void>();
      await _settle(tester);

      // Take attendance: change a mark and save.
      await tester.tap(find.text('تسجيل الحضور').last);
      await _settle(tester);
      // The note dialog closes without errors.
      await tester.tap(find.byTooltip('ملاحظة').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'مريض');
      await tester.tap(find.text('حفظ').last);
      await tester.pumpAndSettle();
      expect(find.text('مريض'), findsOneWidget);
      await tester.tap(find.text('متأخر').first);
      await tester.pump();
      expect(find.text('حفظ الحضور'), findsOneWidget);
      await tester.tap(find.text('حفظ الحضور'));
      await _settle(tester);
      expect(find.text('حفظ الحضور'), findsNothing);
      // Let the success toast time out.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  }
}
