import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/text_prompt.dart';
import '../../data/model/calendar/calendar_models.dart';
import '../../data/model/student/student_model.dart';
import 'settings_controller.dart';

/// Levels, study weekdays and holidays.
class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  /// Saturday first, the way the week is read locally.
  static const _week = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  static String dayName(int weekday) {
    // 2024-01-01 was a Monday.
    return DateFormat('EEEE', 'ar').format(DateTime(2024, 1, weekday));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings'.tr)),
      body: Obx(() {
        final calendar = controller.calendar.value;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Section(
                  title: 'Levels'.tr,
                  hint: 'Levels hint'.tr,
                  action: AppButton(
                    label: 'Add level'.tr,
                    iconAsset: AppIcons.add,
                    compact: true,
                    expand: false,
                    variant: AppButtonVariant.soft,
                    onPressed: () => _editLevel(null),
                  ),
                  children: [
                    for (final level in controller.levels)
                      _Row(
                        title: level.name,
                        subtitle:
                            '${Gender.male.label} ${level.maleCount} · ${Gender.female.label} ${level.femaleCount}',
                        onEdit: () => _editLevel(level),
                        onDelete: () => _deleteLevel(level),
                      ),
                  ],
                ),
                _Section(
                  title: 'Study days'.tr,
                  hint: 'Study days hint'.tr,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final day in _week)
                          FilterChip(
                            label: Text(dayName(day)),
                            selected: calendar.weekdays.contains(day),
                            onSelected: (_) => controller.toggleWeekday(day),
                            selectedColor: AppColors.primarySoft,
                            checkmarkColor: AppColors.primary,
                            side: BorderSide(
                              color: calendar.weekdays.contains(day) ? AppColors.primary : AppColors.border,
                            ),
                            labelStyle: AppTextStyles.body.copyWith(fontSize: 14),
                          ),
                      ],
                    ),
                  ],
                ),
                _Section(
                  title: 'Holidays'.tr,
                  hint: 'Holidays hint'.tr,
                  action: AppButton(
                    label: 'Add holiday'.tr,
                    iconAsset: AppIcons.add,
                    compact: true,
                    expand: false,
                    variant: AppButtonVariant.soft,
                    onPressed: () => _editHoliday(context, null),
                  ),
                  children: [
                    if (calendar.holidays.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No holidays'.tr, style: AppTextStyles.caption),
                      ),
                    for (final holiday in calendar.holidays)
                      _Row(
                        title: holiday.name,
                        subtitle: holiday.from == holiday.to
                            ? displayDate(holiday.from)
                            : '${holiday.from}  ${'to'.tr}  ${holiday.to}',
                        onEdit: () => _editHoliday(context, holiday),
                        onDelete: () => _deleteHoliday(holiday),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _editLevel(LevelModel? level) async {
    final name = await promptText(
      title: level == null ? 'Add level'.tr : 'Rename level'.tr,
      label: 'Level name'.tr,
      initial: level?.name ?? '',
    );
    if (name == null || name.trim().isEmpty) return;
    await controller.saveLevel(id: level?.id, name: name);
  }

  Future<void> _deleteLevel(LevelModel level) async {
    if (!await confirmDialog(title: 'Confirm delete', message: 'Delete this level?')) return;
    await controller.deleteLevel(level.id!);
  }

  Future<void> _editHoliday(BuildContext context, HolidayModel? holiday) async {
    final start = parseDate(holiday?.from) ?? today();
    final end = parseDate(holiday?.to) ?? start;
    final range = await showDateRangePicker(
      context: context,
      helpText: 'Holiday days'.tr,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: start, end: end),
    );
    if (range == null) return;
    final name = await promptText(title: 'Holiday name'.tr, label: 'Holiday name'.tr, initial: holiday?.name ?? '');
    if (name == null || name.trim().isEmpty) return;
    await controller.saveHoliday(
      HolidayModel(id: holiday?.id, name: name, from: dateKey(range.start), to: dateKey(range.end)),
    );
  }

  Future<void> _deleteHoliday(HolidayModel holiday) async {
    if (!await confirmDialog(title: 'Confirm delete', message: 'Delete this holiday?')) return;
    await controller.deleteHoliday(holiday.id!);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.hint, this.action});

  final String title;
  final String? hint;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.title)),
              ?action,
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: AppTextStyles.caption.copyWith(fontSize: 13)),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, required this.onEdit, required this.onDelete});

  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          IconButton(tooltip: 'Edit'.tr, onPressed: onEdit, icon: const AppIcon(AppIcons.edit, size: 18)),
          IconButton(
            tooltip: 'Delete'.tr,
            onPressed: onDelete,
            icon: const AppIcon(AppIcons.delete, size: 18, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
