import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/local/failures.dart';
import '../../data/model/common/import_report.dart';
import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import '../constant/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/custom_snack_bar.dart';
import 'excel_file.dart';

/// Builds an .xlsx file, then lets the user save it to the device or share it.
Future<void> deliverExcel(
  Future<Either<Failure, List<int>>> Function() build,
  String filename, {
  required RxBool busy,
}) async {
  if (busy.value) return;
  busy.value = true;
  final Either<Failure, List<int>> result;
  try {
    result = await build();
  } finally {
    busy.value = false;
  }
  await result.fold((failure) async => customSnackBar(title: 'Error', message: failure.message, isDone: false), (
    bytes,
  ) async {
    final share = await Get.bottomSheet<bool>(_DeliverSheet(filename: filename), backgroundColor: AppColors.white);
    if (share == null) return;
    try {
      if (share) {
        await shareExcel(bytes, filename);
      } else if (await saveExcel(bytes, filename)) {
        customSnackBar(title: 'Done', message: 'File saved');
      }
    } catch (e) {
      customSnackBar(title: 'Error', message: e.toString(), isDone: false);
    }
  });
}

/// Picks an .xlsx file, imports it and shows what was added and what was rejected.
/// Returns true when at least one row was imported.
Future<bool> importExcel(
  Future<Either<Failure, ImportReport>> Function(List<int> bytes) run, {
  required RxBool busy,
}) async {
  if (busy.value) return false;
  final List<int>? bytes;
  try {
    bytes = await pickExcel();
  } catch (e) {
    customSnackBar(title: 'Error', message: e.toString(), isDone: false);
    return false;
  }
  if (bytes == null) return false;
  busy.value = true;
  final Either<Failure, ImportReport> result;
  try {
    result = await run(bytes);
  } finally {
    busy.value = false;
  }
  return result.fold(
    (failure) {
      customSnackBar(title: 'Error', message: failure.message, isDone: false);
      return false;
    },
    (report) {
      Get.dialog(_ImportReportDialog(report: report));
      return report.imported > 0;
    },
  );
}

class _DeliverSheet extends StatelessWidget {
  const _DeliverSheet({required this.filename});

  final String filename;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('File ready'.tr, style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(filename, style: AppTextStyles.caption, textDirection: TextDirection.ltr),
            const SizedBox(height: 16),
            AppButton(
              label: 'Save to device'.tr,
              iconAsset: AppIcons.download,
              onPressed: () => Get.back(result: false),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Share'.tr,
              iconAsset: AppIcons.upload,
              variant: AppButtonVariant.secondary,
              onPressed: () => Get.back(result: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportReportDialog extends StatelessWidget {
  const _ImportReportDialog({required this.report});

  final ImportReport report;

  @override
  Widget build(BuildContext context) {
    final lines = [
      ('Added'.tr, report.added, AppColors.success),
      ('Updated'.tr, report.updated, AppColors.primary),
      if (report.skipped > 0) ('Skipped empty rows'.tr, report.skipped, AppColors.textSecondary),
      ('Rejected rows'.tr, report.errors.length, AppColors.danger),
    ];
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Import result'.tr, style: AppTextStyles.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(line.$1, style: AppTextStyles.body.copyWith(fontSize: 15))),
                    Text('${line.$2}', style: AppTextStyles.title.copyWith(color: line.$3)),
                  ],
                ),
              ),
            if (report.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(color: const Color(0xFFF8E8E6), borderRadius: BorderRadius.circular(10)),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final error in report.errors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(error, style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [AppButton(label: 'OK'.tr, compact: true, expand: false, onPressed: Get.back)],
    );
  }
}
