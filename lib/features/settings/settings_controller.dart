import 'package:dartz/dartz.dart';
import 'package:get/get.dart';

import '../../core/utils/handle_request.dart';
import '../../data/local/failures.dart';
import '../../data/model/calendar/calendar_models.dart';
import '../../data/model/student/student_model.dart';
import '../../data/repo/calendar_repository.dart';
import '../../data/repo/student_repository.dart';

/// Levels and the study calendar. Every screen reads them from here, so a change in the
/// settings shows up everywhere at once.
class SettingsController extends GetxController {
  SettingsController(this._students, this._calendar);

  final StudentRepository _students;
  final CalendarRepository _calendar;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errMessage = RxnString();

  final levels = <LevelModel>[].obs;
  final calendar = const WorkCalendar(weekdays: WorkCalendar.defaultWeekdays).obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    await handleRequest(_students.levels, isLoading: isLoading, errMessage: errMessage, onSuccess: levels.assignAll);
    await handleRequest(
      _calendar.load,
      isLoading: isLoading,
      errMessage: errMessage,
      onSuccess: (value) {
        calendar.value = value;
      },
    );
  }

  Future<bool> saveLevel({int? id, required String name}) {
    return _run(() => _students.saveLevel(id: id, name: name));
  }

  Future<bool> deleteLevel(int id) => _run(() => _students.deleteLevel(id), message: 'Deleted');

  Future<bool> toggleWeekday(int weekday) {
    final days = {...calendar.value.weekdays};
    days.contains(weekday) ? days.remove(weekday) : days.add(weekday);
    return _run(() => _calendar.saveWeekdays(days));
  }

  Future<bool> saveHoliday(HolidayModel holiday) => _run(() => _calendar.saveHoliday(holiday));

  Future<bool> deleteHoliday(int id) => _run(() => _calendar.deleteHoliday(id), message: 'Deleted');

  Future<bool> _run<T>(Future<Either<Failure, T>> Function() request, {String message = 'Saved'}) async {
    var done = false;
    await handleRequest(
      request,
      isLoading: isSaving,
      errMessage: errMessage,
      successMessage: message.tr,
      onSuccess: (_) async {
        done = true;
        await load();
      },
    );
    return done;
  }
}
