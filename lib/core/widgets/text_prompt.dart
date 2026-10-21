import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_text_styles.dart';

/// Asks for one line (or a few lines) of text. Resolves to null when cancelled.
///
/// The dialog owns its text controller, so it is only disposed once the closing
/// animation has finished.
Future<String?> promptText({required String title, required String label, String initial = '', int maxLines = 1}) {
  return Get.dialog<String>(_TextPrompt(title: title, label: label, initial: initial, maxLines: maxLines));
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.label, required this.initial, required this.maxLines});

  final String title;
  final String label;
  final String initial;
  final int maxLines;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      title: Text(widget.title, style: AppTextStyles.title),
      content: TextField(
        controller: _field,
        autofocus: true,
        minLines: widget.maxLines > 1 ? 2 : 1,
        maxLines: widget.maxLines,
        decoration: InputDecoration(labelText: widget.label),
        textInputAction: widget.maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
        onSubmitted: widget.maxLines > 1 ? null : (text) => Get.back(result: text),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: Text('Cancel'.tr)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
          onPressed: () => Get.back(result: _field.text),
          child: Text('Save'.tr),
        ),
      ],
    );
  }
}
