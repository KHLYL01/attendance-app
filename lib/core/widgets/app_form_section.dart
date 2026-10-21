import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_icons.dart';
import '../constant/app_text_styles.dart';
import 'app_button.dart';

class AppFormBlock {
  const AppFormBlock({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;
}

class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    this.children = const [],
    this.slides,
    required this.submitLabel,
    required this.onSubmit,
    this.loading = false,
    this.formKey,
    this.onDelete,
    this.deleteLabel,
  });

  final List<Widget> children;
  final List<AppFormBlock>? slides;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool loading;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    final sections = slides;
    if (sections == null) return _legacy(context);
    return _FormBlocks(
      blocks: sections,
      submitLabel: submitLabel,
      onSubmit: onSubmit,
      loading: loading,
      formKey: formKey,
      onDelete: onDelete,
      deleteLabel: deleteLabel,
    );
  }

  Widget _legacy(BuildContext context) {
    final fields = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      fields.add(children[i]);
      if (i != children.length - 1) fields.add(const SizedBox(height: 16));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: landscape ? 32 : 16, vertical: 16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...fields,
                    const SizedBox(height: 16),
                    AppButton(label: submitLabel, onPressed: onSubmit, loading: loading),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _confirmThenDelete(VoidCallback? onDelete) async {
  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Confirm delete'.tr, style: AppTextStyles.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Delete this record?'.tr, style: AppTextStyles.body),
          const SizedBox(height: 16),
          AppButton(
            label: 'Cancel'.tr,
            variant: AppButtonVariant.secondary,
            compact: true,
            onPressed: () => Get.back(result: false),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Delete'.tr,
            iconAsset: AppIcons.delete,
            variant: AppButtonVariant.danger,
            compact: true,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    ),
  );
  if (confirmed == true) onDelete?.call();
}

class AppFormSwitch extends StatelessWidget {
  const AppFormSwitch({super.key, required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.body.copyWith(fontSize: 15)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _FormBlocks extends StatelessWidget {
  const _FormBlocks({
    required this.blocks,
    required this.submitLabel,
    required this.onSubmit,
    required this.loading,
    required this.formKey,
    required this.onDelete,
    required this.deleteLabel,
  });

  final List<AppFormBlock> blocks;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool loading;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                for (var i = 0; i < blocks.length; i++) ...[if (i > 0) const SizedBox(height: 28), _block(blocks[i])],
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    AppButton(
                      label: submitLabel,
                      iconAsset: AppIcons.check,
                      loading: loading,
                      onPressed: loading ? null : onSubmit,
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(height: 8),
                      AppButton(
                        label: deleteLabel ?? 'Delete'.tr,
                        iconAsset: AppIcons.delete,
                        variant: AppButtonVariant.danger,
                        onPressed: loading ? null : () => _confirmThenDelete(onDelete),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(AppFormBlock block) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  block.title,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
              ),
              if (block.subtitle != null) Text(block.subtitle!, style: AppTextStyles.caption),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _spaced(block.children)),
          ),
        ),
      ],
    );
  }

  List<Widget> _spaced(List<Widget> children) {
    final fields = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      fields.add(children[i]);
      if (i != children.length - 1) fields.add(const SizedBox(height: 14));
    }
    return fields;
  }
}
