import 'package:flutter/material.dart';

import '../../data/model/attendance/attendance_models.dart';
import '../animations/app_motion.dart';
import '../constant/app_colors.dart';
import '../constant/app_text_styles.dart';

Color statusColor(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => AppColors.success,
  AttendanceStatus.absent => AppColors.danger,
  AttendanceStatus.late => AppColors.inProgress,
  AttendanceStatus.excused => AppColors.excused,
};

/// A read-only coloured label for a status.
class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip(this.status, {super.key});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

/// Four tappable pills. Tapping the selected one again clears it.
class AttendanceStatusSelector extends StatelessWidget {
  const AttendanceStatusSelector({super.key, required this.value, required this.onChanged, this.dense = false});

  final AttendanceStatus? value;
  final ValueChanged<AttendanceStatus?> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: [for (final status in AttendanceStatus.values) _pill(status)]);
  }

  Widget _pill(AttendanceStatus status) {
    final selected = value == status;
    final color = statusColor(status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(selected ? null : status),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 6 : 8),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Text(
            status.label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}
