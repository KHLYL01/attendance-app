import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/attendance_status_chip.dart';
import '../../core/widgets/custom_loading.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../../data/model/student/student_model.dart';
import 'students_controller.dart';
import 'students_page.dart';

/// A student's page: identity, then attendance and absence rates for this month or for
/// their time in the current level.
class StudentDetails extends GetView<StudentsController> {
  const StudentDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final student = controller.selected.value;
      if (student == null) return const SizedBox.shrink();
      final stats = controller.stats.value;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(student: student, onEdit: () => openStudentForm(context, student)),
          const SizedBox(height: 16),
          SegmentedButton<StatsPeriod>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: StatsPeriod.month, label: Text('This month'.tr)),
              ButtonSegment(value: StatsPeriod.level, label: Text('Current level'.tr)),
            ],
            selected: {controller.period.value},
            onSelectionChanged: (value) => controller.setPeriod(value.first),
          ),
          const SizedBox(height: 8),
          if (stats != null)
            Text(
              '${'Since'.tr} ${displayDate(stats.from)}',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 12),
          if (stats == null)
            controller.statsLoading.value
                ? const SizedBox(height: 220, child: CustomLoading(style: LoadingStyle.kpi))
                : const SizedBox.shrink()
          else ...[
            _Rates(stats: stats),
            const SizedBox(height: 12),
            _Counts(stats: stats),
            const SizedBox(height: 20),
            Text('Records in this period'.tr, style: AppTextStyles.title),
            const SizedBox(height: 8),
            if (stats.recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No records in this period'.tr, style: AppTextStyles.caption, textAlign: TextAlign.center),
              )
            else
              for (final record in stats.recent) _RecordLine(record: record),
          ],
        ],
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.student, required this.onEdit});

  final StudentModel student;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            child: Text(
              student.name.isEmpty ? '؟' : student.name.characters.first,
              style: AppTextStyles.title.copyWith(color: AppColors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: AppTextStyles.title.copyWith(color: AppColors.white)),
                const SizedBox(height: 2),
                Text(student.groupLabel, style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accentOnInk, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${'No.'.tr} ${student.code}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Edit'.tr,
            iconAsset: AppIcons.edit,
            variant: AppButtonVariant.soft,
            compact: true,
            expand: false,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _Rates extends StatelessWidget {
  const _Rates({required this.stats});

  final StudentStats stats;

  @override
  Widget build(BuildContext context) {
    final summary = stats.summary;
    final empty = summary.total == 0;
    return Row(
      children: [
        Expanded(
          child: _RateCard(label: 'Attendance rate'.tr, value: empty ? null : summary.rate, color: AppColors.success),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RateCard(
            label: 'Absence rate'.tr,
            value: empty ? null : summary.absenceRate,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.label, required this.value, required this.color});

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(
            value == null ? '—' : '${value!.toStringAsFixed(0)}%',
            style: AppTextStyles.display.copyWith(color: color, fontSize: 30),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value ?? 0) / 100,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.stats});

  final StudentStats stats;

  @override
  Widget build(BuildContext context) {
    final summary = stats.summary;
    final items = [
      ('Study days'.tr, stats.workingDays, AppColors.textPrimary),
      for (final status in AttendanceStatus.values)
        (
          status.label,
          switch (status) {
            AttendanceStatus.present => summary.present,
            AttendanceStatus.absent => summary.absent,
            AttendanceStatus.late => summary.late,
            AttendanceStatus.excused => summary.excused,
          },
          statusColor(status),
        ),
      ('Not recorded'.tr, stats.unrecorded, AppColors.textSecondary),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: 92,
              child: Column(
                children: [
                  Text('${item.$2}', style: AppTextStyles.headline.copyWith(color: item.$3, fontSize: 22)),
                  Text(item.$1, style: AppTextStyles.caption.copyWith(fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.record});

  final AttendanceRecord record;

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
                Text(displayDate(record.date), style: AppTextStyles.body.copyWith(fontSize: 14)),
                if ((record.note ?? '').isNotEmpty)
                  Text(record.note!, style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.accent)),
              ],
            ),
          ),
          AttendanceStatusChip(record.status),
        ],
      ),
    );
  }
}
