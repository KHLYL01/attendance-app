import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/custom_loading.dart';
import '../../core/widgets/excel_menu.dart';
import '../../core/widgets/group_filter.dart';
import '../../core/widgets/record_count.dart';
import '../../data/model/student/student_model.dart';
import '../../data/repo/student_repository.dart';
import 'student_details.dart';
import 'student_form.dart';
import 'students_controller.dart';

/// Opens a student's page: a side panel on wide screens, a new page on phones.
void openStudentDetails(BuildContext context, StudentModel student) {
  final controller = Get.find<StudentsController>();
  controller.showDetails(student);
  if (!context.useWebLayout) {
    Get.to(() => const StudentDetailsPage())?.then((_) => controller.closePanel());
  }
}

/// Opens a student's page on top of any screen, e.g. from the records summary.
Future<void> openStudentPage(int studentId) async {
  final result = await Get.find<StudentRepository>().student(studentId);
  final student = result.fold((_) => null, (value) => value);
  if (student == null) return;
  final controller = Get.find<StudentsController>();
  controller.showDetails(student);
  await Get.to(() => const StudentDetailsPage());
  controller.closePanel();
}

/// Opens the add/edit form the same way.
void openStudentForm(BuildContext context, StudentModel? student) {
  final controller = Get.find<StudentsController>();
  final fromDetails = controller.panel.value == StudentPanel.details;
  controller.showForm(student);
  if (!context.useWebLayout) {
    Get.to(() => StudentFormPage(isNew: student == null))?.then((_) {
      // Back from editing a student lands on their page again.
      if (fromDetails && controller.selected.value != null) {
        controller.showDetails(controller.selected.value!);
      } else if (!fromDetails) {
        controller.closePanel();
      }
    });
  }
}

/// Phone page around [StudentDetails]. Each pushed page is its own class: GetX refuses to
/// push a route whose page type matches the current one, and anonymous builders all match.
class StudentDetailsPage extends StatelessWidget {
  const StudentDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student page'.tr)),
      body: const StudentDetails(),
    );
  }
}

/// Phone page around [StudentForm].
class StudentFormPage extends StatelessWidget {
  const StudentFormPage({super.key, required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New student'.tr : 'Edit student'.tr)),
      body: const StudentForm(),
    );
  }
}

class StudentsPage extends GetView<StudentsController> {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final panel = controller.panel.value;
      const list = _StudentList();
      if (!context.useWebLayout || panel == StudentPanel.none) return list;
      return Row(
        children: [
          const Expanded(child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          panel == StudentPanel.details
                              ? 'Student page'.tr
                              : controller.selected.value == null
                              ? 'New student'.tr
                              : 'Edit student'.tr,
                          style: AppTextStyles.title,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close'.tr,
                        onPressed: controller.closePanel,
                        icon: const AppIcon(AppIcons.close, size: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(child: panel == StudentPanel.form ? const StudentForm() : const StudentDetails()),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _StudentList extends StatefulWidget {
  const _StudentList();

  @override
  State<_StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<_StudentList> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = Get.find<StudentsController>().query.value;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StudentsController>();
    return Obx(() {
      final rows = controller.filtered;
      final searching = controller.query.value.isNotEmpty || !controller.group.value.isEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchField(controller: _search, onChanged: (value) => controller.query.value = value),
                const SizedBox(height: 8),
                GroupFilterBar(
                  levels: controller.levels,
                  value: controller.group.value,
                  onChanged: (value) => controller.group.value = value,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ExcelMenu(
                      busy: controller.isExcelBusy.value,
                      onSelected: (action) => switch (action) {
                        ExcelAction.template => controller.downloadTemplate(),
                        ExcelAction.import => controller.importStudents(),
                        ExcelAction.export => controller.exportStudents(),
                      },
                    ),
                    const Spacer(),
                    AppButton(
                      label: 'Add student'.tr,
                      iconAsset: AppIcons.add,
                      compact: true,
                      expand: false,
                      onPressed: () => openStudentForm(context, null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          RecordCountBar(label: 'Students', total: controller.students.length, results: searching ? rows.length : null),
          Expanded(
            child: controller.isLoading.value && controller.students.isEmpty
                ? CustomLoading(style: context.useWebLayout ? LoadingStyle.table : LoadingStyle.list)
                : RefreshIndicator(
                    onRefresh: controller.load,
                    child: controller.students.isEmpty
                        ? EmptyState(title: 'No students yet'.tr, hint: 'Add students hint'.tr)
                        : AppDataTable(
                            layout: context.useWebLayout ? AppTableLayout.sheet : AppTableLayout.cards,
                            columns: [
                              AppTableColumn('Name'.tr, width: 200, flex: 3),
                              AppTableColumn('Student number'.tr, width: 110),
                              AppTableColumn('Level'.tr, width: 130),
                              AppTableColumn('Group'.tr, width: 90),
                            ],
                            rows: [
                              for (final student in rows)
                                [
                                  Text(
                                    student.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  AppTableText(student.code),
                                  AppTableText(student.levelName ?? '—'),
                                  AppTableText(student.gender.label),
                                ],
                            ],
                            onRowTap: (index) => openStudentDetails(context, rows[index]),
                          ),
                  ),
          ),
        ],
      );
    });
  }
}
