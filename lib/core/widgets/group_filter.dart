import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/model/student/student_model.dart';
import '../constant/app_colors.dart';
import '../constant/app_text_styles.dart';

/// A row of level chips and a row of boys/girls chips.
class GroupFilterBar extends StatelessWidget {
  const GroupFilterBar({super.key, required this.levels, required this.value, required this.onChanged});

  final List<LevelModel> levels;
  final GroupFilter value;
  final ValueChanged<GroupFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row([
          _chip('All levels'.tr, value.levelId == null, () => onChanged(GroupFilter(gender: value.gender))),
          for (final level in levels)
            _chip(
              level.name,
              value.levelId == level.id,
              () => onChanged(GroupFilter(levelId: level.id, gender: value.gender)),
            ),
        ]),
        _row([
          _chip('Boys and girls'.tr, value.gender == null, () => onChanged(GroupFilter(levelId: value.levelId))),
          for (final gender in Gender.values)
            _chip(
              gender.label,
              value.gender == gender,
              () => onChanged(GroupFilter(levelId: value.levelId, gender: gender)),
            ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> chips) {
    return SizedBox(
      height: 40,
      child: ListView(scrollDirection: Axis.horizontal, children: chips),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 4, bottom: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: AppTextStyles.caption.copyWith(
          color: active ? AppColors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.white,
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// A centred icon-free message for empty lists, with an optional hint line.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint!, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
