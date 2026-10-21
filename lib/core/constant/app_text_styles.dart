import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Effra';

  static TextStyle get display =>
      const TextStyle(fontFamily: fontFamily, fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary);

  static TextStyle get headline =>
      const TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static TextStyle get title =>
      const TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static TextStyle get body =>
      const TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary);

  static TextStyle get caption => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}
