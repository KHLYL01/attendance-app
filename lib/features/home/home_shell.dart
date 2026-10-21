import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/animations/app_entrance.dart';
import '../../core/constant/app_icons.dart';
import '../../core/widgets/adaptive_scaffold.dart';
import '../../core/widgets/app_icon.dart';
import '../attendance/attendance_page.dart';
import '../dashboard/dashboard_page.dart';
import '../records/records_page.dart';
import '../students/students_page.dart';
import 'home_controller.dart';

class HomeShell extends GetView<HomeController> {
  const HomeShell({super.key});

  static const _icons = [AppIcons.dashboard, AppIcons.students, AppIcons.attendance, AppIcons.records];

  static const _sections = ['Overview', 'Institute', 'Daily work', 'Insights'];

  @override
  Widget build(BuildContext context) {
    final labels = ['Dashboard'.tr, 'Students'.tr, 'Take attendance'.tr, 'Records'.tr];
    final subtitles = [
      'Offline mode'.tr,
      'Students are added separately from attendance'.tr,
      'Pick a day and mark each student'.tr,
      'Attendance history, summary and Excel'.tr,
    ];

    return Obx(() {
      final section = controller.section.value;
      return AdaptiveScaffold(
        title: labels[section],
        subtitle: subtitles[section],
        selectedIndex: section,
        onSelected: controller.selectSection,
        actions: [
          IconButton(
            tooltip: 'Settings'.tr,
            onPressed: controller.openSettings,
            icon: const AppIcon(AppIcons.settings, size: 22),
          ),
        ],
        destinations: [
          for (var i = 0; i < labels.length; i++)
            AdaptiveDestination(label: labels[i], iconAsset: _icons[i], section: _sections[i]),
        ],
        body: AppEntrance(
          key: ValueKey('section-$section'),
          child: switch (section) {
            HomeSection.students => const StudentsPage(),
            HomeSection.attendance => const AttendancePage(),
            HomeSection.records => const RecordsPage(),
            _ => const DashboardPage(),
          },
        ),
      );
    });
  }
}
