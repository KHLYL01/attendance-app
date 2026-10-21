import '../common/json_parse.dart';

/// Each level is split into a boys' group and a girls' group.
enum Gender {
  male('MALE', 'ذكور'),
  female('FEMALE', 'إناث');

  const Gender(this.value, this.label);

  /// Stored in the database.
  final String value;

  /// Shown in the app and written to Excel.
  final String label;

  static Gender? fromValue(String? value) {
    for (final gender in values) {
      if (gender.value == value) return gender;
    }
    return null;
  }

  /// Accepts what people type in Excel.
  static Gender? parse(String? text) {
    final value = text?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return switch (value) {
      'ذكور' || 'ذكر' || 'شباب' || 'بنين' || 'طلاب' || 'm' || 'male' => male,
      'إناث' || 'اناث' || 'أنثى' || 'انثى' || 'بنات' || 'طالبات' || 'f' || 'female' => female,
      _ => null,
    };
  }
}

class LevelModel {
  const LevelModel({this.id, required this.name, this.sortOrder = 0, this.studentCount = 0, this.femaleCount = 0});

  final int? id;
  final String name;
  final int sortOrder;

  /// Filled when listing levels for the settings screen.
  final int studentCount;
  final int femaleCount;

  int get maleCount => studentCount - femaleCount;

  factory LevelModel.fromRow(Map<String, dynamic> row) {
    return LevelModel(
      id: asInt(row['id']),
      name: asString(row['name']) ?? '',
      sortOrder: asInt(row['sort_order']) ?? 0,
      studentCount: asInt(row['student_count']) ?? 0,
      femaleCount: asInt(row['female_count']) ?? 0,
    );
  }
}

class StudentModel {
  const StudentModel({
    this.id,
    this.code = '',
    required this.name,
    required this.levelId,
    required this.gender,
    this.levelName,
    this.levelSince,
  });

  final int? id;

  /// The student's unique number, given automatically when the student is added.
  final String code;
  final String name;
  final int levelId;
  final Gender gender;

  /// Joined from the levels table.
  final String? levelName;

  /// yyyy-MM-dd the student was moved to their current level, or null if they never moved.
  /// Used for "current level" statistics.
  final String? levelSince;

  /// "المستوى الأول · ذكور"
  String get groupLabel => [levelName, gender.label].whereType<String>().join(' · ');

  factory StudentModel.fromRow(Map<String, dynamic> row) {
    return StudentModel(
      id: asInt(row['id']),
      code: asString(row['code']) ?? '',
      name: asString(row['name']) ?? '',
      levelId: asInt(row['level_id']) ?? 0,
      gender: Gender.fromValue(asString(row['gender'])) ?? Gender.male,
      levelName: asString(row['level_name']),
      levelSince: asString(row['level_since']),
    );
  }

  StudentModel copyWith({int? id, String? code, String? levelSince}) {
    return StudentModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name,
      levelId: levelId,
      gender: gender,
      levelName: levelName,
      levelSince: levelSince ?? this.levelSince,
    );
  }
}

/// Narrows students (and their records) to a level and/or a gender group.
class GroupFilter {
  const GroupFilter({this.levelId, this.gender});

  final int? levelId;
  final Gender? gender;

  bool get isEmpty => levelId == null && gender == null;

  bool matches(StudentModel student) {
    return (levelId == null || student.levelId == levelId) && (gender == null || student.gender == gender);
  }

  /// SQL conditions on the students table aliased as [alias].
  (List<String>, List<Object?>) sql(String alias) {
    return (
      [if (levelId != null) '$alias.level_id = ?', if (gender != null) '$alias.gender = ?'],
      [?levelId, ?gender?.value],
    );
  }
}
