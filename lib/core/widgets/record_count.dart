import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_text_styles.dart';

class RecordCountBar extends StatelessWidget {
  const RecordCountBar({super.key, required this.total, this.results, this.label = 'Records'});

  final int total;
  final int? results;

  /// Translation key of what is being counted.
  final String label;

  @override
  Widget build(BuildContext context) {
    final searching = results != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Text(
        searching ? '${label.tr}: $total    ${'Results'.tr}: $results' : '${label.tr}: $total',
        style: AppTextStyles.caption,
      ),
    );
  }
}
