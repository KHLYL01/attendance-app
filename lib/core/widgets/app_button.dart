import 'package:flutter/material.dart';

import '../constant/app_colors.dart';
import '../constant/app_text_styles.dart';
import 'app_icon.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, soft }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.iconAsset,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final String? iconAsset;
  final EdgeInsetsGeometry padding;
  final bool loading;
  final bool expand;
  final bool compact;

  static const double height = 52;
  static const double compactHeight = 40;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = compact ? compactHeight : height;
    final radius = compact ? 10.0 : 12.0;
    final child = loading
        ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _foreground))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (iconAsset != null) ...[
                AppIcon(iconAsset!, size: compact ? 16 : 18, color: _foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label, style: _labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final size = Size(expand ? double.infinity : 0, buttonHeight);

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          minimumSize: size,
          padding: padding,
          shape: shape,
        ),
        child: child,
      ),
      AppButtonVariant.soft => FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primarySoft,
          foregroundColor: AppColors.primary,
          minimumSize: size,
          padding: padding,
          shape: shape,
        ),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF8E8E6),
          foregroundColor: AppColors.danger,
          minimumSize: size,
          padding: padding,
          shape: shape,
          side: const BorderSide(color: Color(0xFFE7C4C0)),
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: size,
          padding: padding,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.white,
          shape: shape,
        ),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: size,
          padding: padding,
          shape: shape,
        ),
        child: child,
      ),
    };

    if (expand) return button;
    return Align(alignment: AlignmentDirectional.centerStart, child: button);
  }

  TextStyle get _labelStyle {
    final base = compact ? AppTextStyles.body.copyWith(fontSize: 14) : AppTextStyles.title;
    return base.copyWith(color: _foreground, fontWeight: FontWeight.w600);
  }

  Color get _foreground => switch (variant) {
    AppButtonVariant.primary => AppColors.white,
    AppButtonVariant.danger => AppColors.danger,
    AppButtonVariant.ghost => AppColors.textSecondary,
    _ => AppColors.primary,
  };
}

class AppIconAction extends StatelessWidget {
  const AppIconAction({super.key, required this.iconAsset, required this.onPressed, this.tooltip});

  final String iconAsset;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: SizedBox(width: 32, height: 32, child: Center(child: AppIcon(iconAsset, size: 16))),
        ),
      ),
    );
  }
}
