import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import '../constant/app_text_styles.dart';
import 'app_button.dart';

/// Asks before a destructive or unsaved-changes action. Resolves to true on confirm.
Future<bool> confirmDialog({
  required String title,
  required String message,
  String? confirmLabel,
  bool danger = true,
}) async {
  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title.tr, style: AppTextStyles.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message.tr, style: AppTextStyles.body),
          const SizedBox(height: 16),
          AppButton(
            label: 'Cancel'.tr,
            variant: AppButtonVariant.secondary,
            compact: true,
            onPressed: () => Get.back(result: false),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: (confirmLabel ?? 'Delete').tr,
            iconAsset: danger ? AppIcons.delete : AppIcons.check,
            variant: danger ? AppButtonVariant.danger : AppButtonVariant.primary,
            compact: true,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}

enum UnsavedChoice { save, discard }

/// Offers to save, discard or stay when leaving with unsaved changes. Null means stay.
Future<UnsavedChoice?> unsavedChangesDialog() {
  return Get.dialog<UnsavedChoice>(
    AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Unsaved changes'.tr, style: AppTextStyles.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Save attendance before leaving?'.tr, style: AppTextStyles.body),
          const SizedBox(height: 16),
          AppButton(
            label: 'Save and continue'.tr,
            iconAsset: AppIcons.check,
            compact: true,
            onPressed: () => Get.back(result: UnsavedChoice.save),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Discard'.tr,
            iconAsset: AppIcons.delete,
            variant: AppButtonVariant.danger,
            compact: true,
            onPressed: () => Get.back(result: UnsavedChoice.discard),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Stay here'.tr,
            variant: AppButtonVariant.secondary,
            compact: true,
            onPressed: () => Get.back(),
          ),
        ],
      ),
    ),
  );
}
