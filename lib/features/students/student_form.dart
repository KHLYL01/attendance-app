import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constant/app_colors.dart';
import '../../core/constant/app_text_styles.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/utils/validator.dart';
import '../../core/widgets/app_form_section.dart';
import '../../data/model/student/student_model.dart';
import 'students_controller.dart';

/// Add or edit one student: name, level and group. The number is given automatically.
class StudentForm extends GetView<StudentsController> {
  const StudentForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final student = controller.selected.value;
      return _StudentFormBody(key: ValueKey(student?.id ?? 'new'), existing: student);
    });
  }
}

class _StudentFormBody extends StatefulWidget {
  const _StudentFormBody({super.key, this.existing});

  final StudentModel? existing;

  @override
  State<_StudentFormBody> createState() => _StudentFormBodyState();
}

class _StudentFormBodyState extends State<_StudentFormBody> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late int? _levelId = widget.existing?.levelId;
  late Gender? _gender = widget.existing?.gender;
  String? _nextNumber;

  StudentsController get controller => Get.find<StudentsController>();

  @override
  void initState() {
    super.initState();
    if (widget.existing == null) {
      final group = controller.group.value;
      _levelId = group.levelId;
      _gender = group.gender;
      controller.nextNumber().then((value) {
        if (mounted) setState(() => _nextNumber = value);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _close() {
    if (context.useWebLayout) {
      final saved = controller.selected.value;
      saved == null ? controller.closePanel() : controller.showDetails(saved);
    } else {
      Get.back();
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final saved = await controller.save(
      StudentModel(id: widget.existing?.id, name: _name.text.trim(), levelId: _levelId!, gender: _gender!),
    );
    if (saved == null || !mounted) return;
    controller.selected.value = saved;
    _close();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    if (!await controller.delete(id) || !mounted) return;
    controller.selected.value = null;
    if (context.useWebLayout) {
      controller.closePanel();
    } else {
      // Leave both the form and the student's page.
      Get.until((route) => route.isFirst);
      controller.closePanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Obx(
      () => AppFormSection(
        formKey: _formKey,
        submitLabel: existing == null ? 'Add student'.tr : 'Save student'.tr,
        loading: controller.isSaving.value,
        onSubmit: _save,
        onDelete: existing == null ? null : _delete,
        deleteLabel: 'Delete student'.tr,
        slides: [
          AppFormBlock(
            title: 'Student'.tr,
            children: [
              _NumberTile(number: existing?.code ?? _nextNumber, isNew: existing == null),
              TextFormField(
                controller: _name,
                autofocus: existing == null,
                decoration: InputDecoration(labelText: 'Student name'.tr),
                textInputAction: TextInputAction.done,
                validator: (value) => Validator.validateNotEmpty(value, fieldName: 'Student name'),
              ),
            ],
          ),
          AppFormBlock(
            title: 'Level and group'.tr,
            children: [
              DropdownButtonFormField<int>(
                initialValue: controller.levels.any((level) => level.id == _levelId) ? _levelId : null,
                decoration: InputDecoration(
                  labelText: 'Level'.tr,
                  helperText: existing == null ? null : 'Changing level hint'.tr,
                  helperMaxLines: 3,
                ),
                items: [
                  for (final level in controller.levels) DropdownMenuItem(value: level.id, child: Text(level.name)),
                ],
                onChanged: (value) => setState(() => _levelId = value),
                validator: (value) => value == null ? 'Choose a level'.tr : null,
              ),
              FormField<Gender>(
                initialValue: _gender,
                validator: (value) => value == null ? 'Choose a group'.tr : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<Gender>(
                      showSelectedIcon: false,
                      emptySelectionAllowed: true,
                      segments: [
                        for (final gender in Gender.values) ButtonSegment(value: gender, label: Text(gender.label)),
                      ],
                      selected: {?_gender},
                      onSelectionChanged: (value) {
                        setState(() => _gender = value.firstOrNull);
                        field.didChange(_gender);
                      },
                    ),
                    if (field.errorText != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                        child: Text(
                          field.errorText!,
                          style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.number, required this.isNew});

  final String? number;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student number'.tr, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                Text(
                  isNew ? 'Given automatically'.tr : 'Fixed number'.tr,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(number ?? '…', style: AppTextStyles.headline.copyWith(color: AppColors.primary, fontSize: 22)),
        ],
      ),
    );
  }
}
