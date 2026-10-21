import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pie_chart/pie_chart.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/attendance_status_chip.dart';
import '../../core/widgets/custom_loading.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../home/home_controller.dart';
import 'dashboard_controller.dart';

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.ready.value) return const CustomLoading(style: LoadingStyle.analysis);
      final home = Get.find<HomeController>();
      final counts = controller.todayCounts.value;
      final cards = [
        (AppIcons.students, 'Students'.tr, '${controller.studentCount.value}', AppColors.primary, HomeSection.students),
        (AppIcons.groups, 'Levels'.tr, '${controller.levelCount}', AppColors.accent, HomeSection.students),
        (
          AppIcons.attendance,
          'Present today'.tr,
          '${counts.of(AttendanceStatus.present) + counts.of(AttendanceStatus.late)}',
          AppColors.success,
          HomeSection.attendance,
        ),
        (
          AppIcons.close,
          'Absent today'.tr,
          '${counts.of(AttendanceStatus.absent)}',
          AppColors.danger,
          HomeSection.attendance,
        ),
        (
          AppIcons.calendar,
          'Excused today'.tr,
          '${counts.of(AttendanceStatus.excused)}',
          AppColors.excused,
          HomeSection.attendance,
        ),
        (
          AppIcons.reports,
          'Rate this month'.tr,
          '${controller.monthRate.toStringAsFixed(0)}%',
          AppColors.primary,
          HomeSection.records,
        ),
      ];
      return RefreshIndicator(
        onRefresh: controller.load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final chart = _TodayChart(
              counts: counts,
              studentCount: controller.studentCount.value,
              working: controller.todayIsWorking,
            );
            final absent = _MostAbsent(items: controller.mostAbsent);
            final levels = _GroupRates(items: controller.groupRates);
            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _TodayBanner(
                  marked: counts.total,
                  students: controller.studentCount.value,
                  working: controller.todayIsWorking,
                  holiday: controller.todayHoliday,
                  onTap: () => home.selectSection(HomeSection.attendance),
                ),
                const SizedBox(height: 16),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // A fixed height keeps the value readable whatever the font's line height is.
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 6 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 124,
                  ),
                  children: [
                    for (final card in cards)
                      _DashCard(
                        icon: card.$1,
                        label: card.$2,
                        value: card.$3,
                        color: card.$4,
                        onTap: () => home.selectSection(card.$5),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: chart),
                      const SizedBox(width: 16),
                      Expanded(child: levels),
                      const SizedBox(width: 16),
                      Expanded(child: absent),
                    ],
                  )
                else ...[
                  chart,
                  const SizedBox(height: 12),
                  levels,
                  const SizedBox(height: 12),
                  absent,
                ],
              ],
            );
          },
        ),
      );
    });
  }
}

class _TodayBanner extends StatelessWidget {
  const _TodayBanner({
    required this.marked,
    required this.students,
    required this.working,
    required this.holiday,
    required this.onTap,
  });

  final int marked;
  final int students;
  final bool working;
  final String? holiday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = students > 0 && marked >= students;
    final title = !working
        ? (holiday == null ? 'Today is not a study day'.tr : '${'Holiday'.tr}: $holiday')
        : done
        ? 'Today attendance complete'.tr
        : 'Take today attendance'.tr;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayDate(dateKey(today())), style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
                const SizedBox(height: 6),
                Text(title, style: AppTextStyles.title.copyWith(color: AppColors.white)),
                if (working) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${'Marked'.tr}: $marked / $students',
                    style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          if (working) const SizedBox(width: 12),
          if (working)
            AppButton(
              label: done ? 'Review'.tr : 'Start'.tr,
              iconAsset: AppIcons.attendance,
              compact: true,
              expand: false,
              variant: AppButtonVariant.soft,
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppIcon(icon, size: 18, color: color),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(value, style: AppTextStyles.headline.copyWith(color: AppColors.textPrimary)),
              ),
              Text(label, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TodayChart extends StatelessWidget {
  const _TodayChart({required this.counts, required this.studentCount, required this.working});

  final DayCounts counts;
  final int studentCount;
  final bool working;

  @override
  Widget build(BuildContext context) {
    final unmarked = (studentCount - counts.total).clamp(0, studentCount);
    final data = <String, double>{
      for (final status in AttendanceStatus.values) status.label: counts.of(status).toDouble(),
      'Unmarked'.tr: unmarked.toDouble(),
    };
    return _Panel(
      title: 'Today'.tr,
      child: !working || data.values.every((value) => value == 0)
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                working ? 'No chart data'.tr : 'Today is not a study day'.tr,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            )
          : PieChart(
              dataMap: data,
              chartType: ChartType.ring,
              ringStrokeWidth: 26,
              chartRadius: 150,
              colorList: [for (final status in AttendanceStatus.values) statusColor(status), AppColors.border],
              legendOptions: LegendOptions(
                legendPosition: LegendPosition.left,
                legendTextStyle: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
              ),
              chartValuesOptions: const ChartValuesOptions(showChartValueBackground: false, decimalPlaces: 0),
            ),
    );
  }
}

class _MostAbsent extends StatelessWidget {
  const _MostAbsent({required this.items});

  final List<AttendanceSummary> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Most absent this month'.tr,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('No absences this month'.tr, style: AppTextStyles.caption, textAlign: TextAlign.center),
            )
          : Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: AppTextStyles.body.copyWith(fontSize: 15)),
                              Text(
                                '${item.code} · ${item.groupLabel}',
                                style: AppTextStyles.caption.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.absent} ${'absences'.tr}',
                          style: AppTextStyles.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _GroupRates extends StatelessWidget {
  const _GroupRates({required this.items});

  final List<(String, double?, int)> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Attendance by group this month'.tr,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('No students yet'.tr, style: AppTextStyles.caption, textAlign: TextAlign.center),
            )
          : Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.$1, style: AppTextStyles.body.copyWith(fontSize: 14))),
                            Text(
                              item.$2 == null ? '—' : '${item.$2!.toStringAsFixed(0)}%',
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (item.$2 ?? 0) / 100,
                            minHeight: 6,
                            color: AppColors.primary,
                            backgroundColor: AppColors.primarySoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('${item.$3} ${'students'.tr}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
