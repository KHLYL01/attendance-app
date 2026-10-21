import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import '../constant/app_text_styles.dart';
import 'app_icon.dart';

void customSnackBar({
  required String title,
  required String message,
  bool isDone = true,
  Duration? duration,
  bool isDismissible = true,
  bool progress = false,
  bool sticky = false,
}) {
  _showWebToast(
    title: title.tr,
    message: message.tr,
    isDone: isDone,
    progress: progress,
    sticky: sticky,
    duration: duration ?? Duration(seconds: isDone ? 3 : 4),
  );
}

void dismissCustomSnackBar() {
  _currentToast?.remove();
  _currentToast = null;
}

// ─── Web toast ────────────────────────────────────────────────────────────────

OverlayEntry? _currentToast;

void _showWebToast({
  required String title,
  required String message,
  required bool isDone,
  required bool progress,
  required bool sticky,
  required Duration duration,
}) {
  final overlayContext = Get.overlayContext;
  if (overlayContext == null) return;

  _currentToast?.remove();
  _currentToast = null;

  _currentToast = OverlayEntry(
    builder: (_) => _WebToast(
      title: title,
      message: message,
      isDone: isDone,
      progress: progress,
      sticky: sticky,
      onDismiss: () {
        _currentToast?.remove();
        _currentToast = null;
      },
      duration: duration,
    ),
  );

  Overlay.of(overlayContext).insert(_currentToast!);
}

class _WebToast extends StatefulWidget {
  const _WebToast({
    required this.title,
    required this.message,
    required this.isDone,
    required this.progress,
    required this.sticky,
    required this.onDismiss,
    required this.duration,
  });

  final String title;
  final String message;
  final bool isDone;
  final bool progress;
  final bool sticky;
  final VoidCallback onDismiss;
  final Duration duration;

  @override
  State<_WebToast> createState() => _WebToastState();
}

class _WebToastState extends State<_WebToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));

    _slide = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    if (!widget.sticky) Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.progress
        ? AppColors.accent
        : widget.isDone
        ? AppColors.success
        : AppColors.danger;

    final top = MediaQuery.paddingOf(context).top + 12;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شريط الألوان العلوي
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        widget.progress
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
                              )
                            : AppIcon(widget.isDone ? AppIcons.check : AppIcons.error, color: color, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (widget.message.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.message,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: const AppIcon(AppIcons.close, size: 16, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
