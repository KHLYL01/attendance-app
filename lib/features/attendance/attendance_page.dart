import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/attendance_status_chip.dart';
import '../../core/widgets/custom_loading.dart';
import '../../core/widgets/group_filter.dart';
import '../../core/widgets/text_prompt.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../../data/model/student/student_model.dart';
import '../home/home_controller.dart';
import 'attendance_controller.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _search = TextEditingController();

  AttendanceController get controller => Get.find<AttendanceController>();

  @override
  void initState() {
    super.initState();
    _search.text = controller.query.value;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.date.value,
      firstDate: DateTime(2000),
      lastDate: today(),
    );
    if (picked != null) await controller.changeDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final students = controller.visible;
      final working = controller.isWorkingDay;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DateBar(
                  label: displayDate(controller.dateText),
                  isToday: controller.dateText == dateKey(today()),
                  onPrevious: () => controller.shiftDay(-1),
                  onNext: controller.canGoForward ? () => controller.shiftDay(1) : null,
                  onPick: _pickDate,
                ),
                const SizedBox(height: 10),
                GroupFilterBar(
                  levels: controller.levels,
                  value: controller.group.value,
                  onChanged: controller.changeGroup,
                ),
                if (working) ...[
                  const SizedBox(height: 8),
                  AppSearchField(controller: _search, onChanged: (value) => controller.query.value = value),
                  const SizedBox(height: 10),
                  _Counts(controller: controller),
                ],
              ],
            ),
          ),
          Expanded(
            child: !working
                ? _DayOff(holiday: controller.holiday?.name, onPrevious: () => controller.shiftDay(-1))
                : controller.isLoading.value && controller.students.isEmpty
                ? const CustomLoading(style: LoadingStyle.list)
                : controller.students.isEmpty
                ? _NoStudents()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    // Rows are built lazily, outside the page's Obx, so each one listens itself.
                    itemBuilder: (context, index) => Obx(
                      () => _StudentRow(
                        index: index,
                        student: students[index],
                        entry: controller.entries[students[index].id],
                      ),
                    ),
                  ),
          ),
          if (working && controller.students.isNotEmpty) _SaveBar(controller: controller),
        ],
      );
    });
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.label,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final String label;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day'.tr,
            onPressed: onPrevious,
            icon: Transform.flip(
              flipX: true,
              child: const AppIcon(AppIcons.chevron, size: 18, matchTextDirection: true),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppIcon(AppIcons.calendar, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: AppTextStyles.title.copyWith(fontSize: 16, color: AppColors.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isToday) Text('Today'.tr, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day'.tr,
            onPressed: onNext,
            icon: const AppIcon(AppIcons.chevron, size: 18, matchTextDirection: true),
          ),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.controller});

  final AttendanceController controller;

  @override
  Widget build(BuildContext context) => Obx(_build);

  Widget _build() {
    final unmarked = controller.unmarked;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final status in AttendanceStatus.values)
                _count(status.label, controller.count(status), statusColor(status)),
              _count('Unmarked'.tr, unmarked, AppColors.textSecondary),
            ],
          ),
        ),
        if (unmarked > 0)
          AppButton(
            label: 'Rest present'.tr,
            iconAsset: AppIcons.check,
            variant: AppButtonVariant.soft,
            compact: true,
            expand: false,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: () => controller.markRest(AttendanceStatus.present),
          ),
      ],
    );
  }

  Widget _count(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label $value', style: AppTextStyles.caption.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.index, required this.student, required this.entry});

  final int index;
  final StudentModel student;
  final AttendanceEntry? entry;

  Future<void> _editNote() async {
    final note = await promptText(title: student.name, label: 'Note'.tr, initial: entry?.note ?? '', maxLines: 4);
    if (note != null) Get.find<AttendanceController>().setNote(student.id!, note);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AttendanceController>();
    final status = entry?.status;
    final hasNote = (entry?.note ?? '').trim().isNotEmpty;
    return Material(
      color: status == null ? AppColors.white : statusColor(status).withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: status == null ? AppColors.border : statusColor(status).withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final selector = AttendanceStatusSelector(
              value: status,
              dense: true,
              onChanged: (value) => controller.setStatus(student.id!, value),
            );
            final title = Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${index + 1}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${student.code} · ${student.groupLabel}',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                      if (hasNote)
                        Text(
                          entry!.note!,
                          style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.accent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Note'.tr,
                  onPressed: _editNote,
                  icon: AppIcon(AppIcons.edit, size: 18, color: hasNote ? AppColors.accent : AppColors.textSecondary),
                ),
              ],
            );
            if (constraints.maxWidth >= 640) {
              return Row(
                children: [
                  Expanded(child: title),
                  selector,
                  const SizedBox(width: 8),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 6),
                Padding(padding: const EdgeInsetsDirectional.only(start: 28), child: selector),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller});

  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Obx(
          () => AppButton(
            label: controller.dirty.value ? 'Save attendance'.tr : 'Saved'.tr,
            iconAsset: AppIcons.check,
            loading: controller.isSaving.value,
            variant: controller.dirty.value ? AppButtonVariant.primary : AppButtonVariant.soft,
            onPressed: controller.dirty.value ? controller.save : null,
          ),
        ),
      ),
    );
  }
}

class _NoStudents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No students yet'.tr, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Add students before attendance'.tr, style: AppTextStyles.caption, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to students'.tr,
              iconAsset: AppIcons.students,
              variant: AppButtonVariant.soft,
              expand: false,
              compact: true,
              onPressed: () => Get.find<HomeController>().selectSection(HomeSection.students),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayOff extends StatelessWidget {
  const _DayOff({required this.holiday, required this.onPrevious});

  final String? holiday;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: const AppIcon(AppIcons.calendar, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              holiday == null ? 'Not a study day'.tr : '${'Holiday'.tr}: $holiday',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Day off hint'.tr, style: AppTextStyles.caption, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(
              label: 'Previous study day'.tr,
              iconAsset: AppIcons.attendance,
              variant: AppButtonVariant.soft,
              expand: false,
              compact: true,
              onPressed: onPrevious,
            ),
          ],
        ),
      ),
    );
  }
}
