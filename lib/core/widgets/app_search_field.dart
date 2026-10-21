import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import 'app_icon.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search'.tr,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        prefixIcon: const Padding(
          padding: EdgeInsetsDirectional.only(start: 12, end: 4),
          child: AppIcon(AppIcons.search, size: 18, color: AppColors.textSecondary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const AppIcon(AppIcons.close, size: 16, color: AppColors.textSecondary),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
      ),
    );
  }
}
