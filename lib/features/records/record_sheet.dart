import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_icons.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/attendance_status_chip.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../data/model/attendance/attendance_models.dart';
import 'records_controller.dart';

/// Edit or delete a single attendance record.
Future<void> showRecordSheet(AttendanceRecord record) {
  return Get.bottomSheet(
    _RecordSheet(record: record),
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
  );
}

class _RecordSheet extends StatefulWidget {
  const _RecordSheet({required this.record});

  final AttendanceRecord record;

  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  late AttendanceStatus _status = widget.record.status;
  late final _note = TextEditingController(text: widget.record.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = Get.find<RecordsController>();
    final record = widget.record;
    final saved = await controller.updateRecord(
      AttendanceRecord(
        id: record.id,
        studentId: record.studentId,
        date: record.date,
        status: _status,
        note: _note.text,
      ),
    );
    if (saved) Get.back();
  }

  Future<void> _delete() async {
    if (!await confirmDialog(title: 'Confirm delete', message: 'Delete this record?')) return;
    if (await Get.find<RecordsController>().deleteRecord(widget.record.id!)) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<RecordsController>();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.record.studentName ?? '', style: AppTextStyles.title),
            const SizedBox(height: 2),
            Text(
              '${widget.record.studentCode ?? ''} · ${displayDate(widget.record.date)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            AttendanceStatusSelector(
              value: _status,
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Note'.tr),
            ),
            const SizedBox(height: 16),
            Obx(
              () => AppButton(
                label: 'Save'.tr,
                iconAsset: AppIcons.check,
                loading: controller.isSaving.value,
                onPressed: _save,
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Delete record'.tr,
              iconAsset: AppIcons.delete,
              variant: AppButtonVariant.danger,
              onPressed: _delete,
            ),
          ],
        ),
      ),
    );
  }
}
