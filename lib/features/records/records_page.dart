import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_data_table.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/attendance_status_chip.dart';
import '../../core/widgets/custom_loading.dart';
import '../../core/widgets/custom_snack_bar.dart';
import '../../core/widgets/excel_menu.dart';
import '../../core/widgets/group_filter.dart';
import '../../core/widgets/record_count.dart';
import '../../data/model/attendance/attendance_models.dart';
import '../students/students_page.dart';
import 'record_sheet.dart';
import 'records_controller.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final _search = TextEditingController();

  RecordsController get controller => Get.find<RecordsController>();

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

  Future<void> _pickPeriod() async {
    final now = today();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: controller.from.value ?? now, end: controller.to.value ?? now),
    );
    if (range != null) await controller.setPeriod(range.start, range.end);
  }

  Future<void> _onExcel(ExcelAction action) async {
    switch (action) {
      case ExcelAction.template:
        final initial = controller.lastStudyDay();
        if (!controller.isStudyDay(dateKey(initial))) {
          customSnackBar(title: 'Error', message: 'No study days are set', isDone: false);
          return;
        }
        final date = await showDatePicker(
          context: context,
          helpText: 'Template date'.tr,
          // Only past and present study days can be filled in.
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: today(),
          selectableDayPredicate: (day) => controller.isStudyDay(dateKey(day)),
        );
        if (date != null) await controller.downloadTemplate(date);
      case ExcelAction.import:
        await controller.importRecords();
      case ExcelAction.export:
        await controller.exportRecords();
    }
  }

  String _periodLabel() {
    final from = controller.from.value;
    final to = controller.to.value;
    if (from == null && to == null) return 'All dates'.tr;
    // Isolate each date so the Arabic word between them does not flip their digits.
    String iso(DateTime? date) =>
        '${String.fromCharCode(0x2066)}${date == null ? '…' : dateKey(date)}${String.fromCharCode(0x2069)}';
    return '${iso(from)}  ${'to'.tr}  ${iso(to)}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summaryView = controller.view.value == RecordsView.summary;
      final records = controller.filteredRecords;
      final summary = controller.filteredSummary;
      final searching = controller.query.value.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<RecordsView>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: RecordsView.records, label: Text('Records'.tr)),
                    ButtonSegment(value: RecordsView.summary, label: Text('Summary per student'.tr)),
                  ],
                  selected: {controller.view.value},
                  onSelectionChanged: (value) => controller.view.value = value.first,
                ),
                const SizedBox(height: 10),
                AppSearchField(controller: _search, onChanged: (value) => controller.query.value = value),
                const SizedBox(height: 8),
                GroupFilterBar(
                  levels: controller.levels,
                  value: controller.group.value,
                  onChanged: controller.setGroup,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ToolbarButton(icon: AppIcons.calendar, label: _periodLabel(), onTap: _pickPeriod),
                    if (controller.from.value != null || controller.to.value != null)
                      _ToolbarButton(
                        icon: AppIcons.close,
                        label: 'All dates'.tr,
                        onTap: () => controller.setPeriod(null, null),
                      ),
                    if (!summaryView) _statusMenu(),
                    ExcelMenu(busy: controller.isExcelBusy.value, onSelected: _onExcel),
                  ],
                ),
              ],
            ),
          ),
          RecordCountBar(
            label: summaryView ? 'Students' : 'Records',
            total: summaryView ? controller.summary.length : controller.records.length,
            results: searching ? (summaryView ? summary.length : records.length) : null,
          ),
          Expanded(
            child: controller.isLoading.value && controller.records.isEmpty && controller.summary.isEmpty
                ? CustomLoading(style: context.useWebLayout ? LoadingStyle.table : LoadingStyle.list)
                : RefreshIndicator(
                    onRefresh: controller.load,
                    child: summaryView ? _summaryTable(summary) : _recordsTable(records),
                  ),
          ),
        ],
      );
    });
  }

  Widget _statusMenu() {
    final status = controller.statusFilter.value;
    return PopupMenuButton<AttendanceStatus?>(
      offset: const Offset(0, 44),
      color: AppColors.white,
      onSelected: controller.setStatus,
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text('All statuses'.tr)),
        for (final item in AttendanceStatus.values) PopupMenuItem(value: item, child: Text(item.label)),
      ],
      child: _ToolbarButton(icon: AppIcons.filter, label: status?.label ?? 'All statuses'.tr),
    );
  }

  Widget _recordsTable(List<AttendanceRecord> rows) {
    if (controller.records.isEmpty) {
      return EmptyState(title: 'No records in this period'.tr, hint: 'Records hint'.tr);
    }
    return AppDataTable(
      layout: context.useWebLayout ? AppTableLayout.sheet : AppTableLayout.cards,
      columns: [
        AppTableColumn('Name'.tr, width: 190, flex: 3),
        AppTableColumn('Date'.tr, width: 110),
        AppTableColumn('Status'.tr, width: 100),
        AppTableColumn('Student number'.tr, width: 110),
        AppTableColumn('Level and group'.tr, width: 170),
        AppTableColumn('Note'.tr, width: 160, flex: 2),
      ],
      rows: [
        for (final record in rows)
          [
            Text(
              record.studentName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            controller.isStudyDay(record.date)
                ? AppTableText(record.date)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTableText(record.date),
                      Text(
                        'Not counted: not a study day'.tr,
                        style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.inProgress),
                      ),
                    ],
                  ),
            Align(alignment: AlignmentDirectional.centerStart, child: AttendanceStatusChip(record.status)),
            AppTableText(record.studentCode ?? ''),
            AppTableText(record.groupLabel.isEmpty ? '—' : record.groupLabel),
            AppTableText(record.note ?? '—'),
          ],
      ],
      onRowTap: (index) => showRecordSheet(rows[index]),
    );
  }

  Widget _summaryTable(List<AttendanceSummary> rows) {
    if (controller.summary.isEmpty) {
      return EmptyState(title: 'No students yet'.tr, hint: 'Add students hint'.tr);
    }
    return AppDataTable(
      layout: context.useWebLayout ? AppTableLayout.sheet : AppTableLayout.cards,
      columns: [
        AppTableColumn('Name'.tr, width: 190, flex: 3),
        AppTableColumn('Attendance rate'.tr, width: 110),
        AppTableColumn('Absence rate'.tr, width: 110),
        for (final status in AttendanceStatus.values) AppTableColumn(status.label, width: 80),
        AppTableColumn('Student number'.tr, width: 110),
        AppTableColumn('Level and group'.tr, width: 170),
      ],
      rows: [
        for (final item in rows)
          [
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            _Rate(item),
            AppTableText(item.total == 0 ? '—' : '${item.absenceRate.toStringAsFixed(0)}%'),
            AppTableText('${item.present}'),
            AppTableText('${item.absent}'),
            AppTableText('${item.late}'),
            AppTableText('${item.excused}'),
            AppTableText(item.code),
            AppTableText(item.groupLabel.isEmpty ? '—' : item.groupLabel),
          ],
      ],
      onRowTap: (index) => openStudentPage(rows[index].studentId),
    );
  }
}

class _Rate extends StatelessWidget {
  const _Rate(this.item);

  final AttendanceSummary item;

  @override
  Widget build(BuildContext context) {
    if (item.total == 0) return const AppTableText('—');
    final rate = item.rate;
    final color = rate >= 85
        ? AppColors.success
        : rate >= 70
        ? AppColors.inProgress
        : AppColors.danger;
    return Text(
      '${rate.toStringAsFixed(0)}%',
      style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 14),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label, this.onTap});

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: content);
  }
}
