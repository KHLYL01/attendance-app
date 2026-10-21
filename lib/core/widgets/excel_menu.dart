import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import '../constant/app_text_styles.dart';
import 'app_icon.dart';

enum ExcelAction { template, import, export }

/// The "Excel" toolbar button: download the empty template, import a filled one, or export.
class ExcelMenu extends StatelessWidget {
  const ExcelMenu({super.key, required this.onSelected, this.busy = false});

  final ValueChanged<ExcelAction> onSelected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ExcelAction>(
      enabled: !busy,
      tooltip: 'Excel'.tr,
      offset: const Offset(0, 44),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (context) => [
        _item(ExcelAction.template, AppIcons.sheet, 'Download template'.tr),
        _item(ExcelAction.import, AppIcons.upload, 'Import from Excel'.tr),
        _item(ExcelAction.export, AppIcons.download, 'Export to Excel'.tr),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const AppIcon(AppIcons.sheet, size: 16),
            const SizedBox(width: 6),
            Text('Excel'.tr, style: AppTextStyles.body.copyWith(fontSize: 14, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<ExcelAction> _item(ExcelAction value, String icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.body.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
