import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/app_colors.dart';
import '../constant/app_text_styles.dart';

class AppTableColumn {
  const AppTableColumn(this.label, {this.width = 140, this.flex = 1, this.fixed = false, this.center = false});

  final String label;
  final double width;
  final int flex;
  final bool fixed;
  final bool center;
}

enum AppTableLayout { cards, sheet }

class AppDataTable extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.emptyLabel,
    this.layout = AppTableLayout.cards,
    this.shrinkWrap = false,
    this.primary = true,
  });

  final List<AppTableColumn> columns;
  final List<List<Widget>> rows;
  final ValueChanged<int>? onRowTap;
  final String? emptyLabel;
  final AppTableLayout layout;
  final bool shrinkWrap;
  final bool primary;

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  static const _line = AppTableColumn('م', width: 56, fixed: true, center: true);

  final _horizontal = ScrollController();

  List<AppTableColumn> get _columns => [_line, ...widget.columns];

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.layout == AppTableLayout.cards) return _records();
        final width = math.max(0, constraints.maxWidth - 24).toDouble();
        final height = widget.shrinkWrap
            ? 44 + (widget.rows.isEmpty ? 72.0 : 52.0 * widget.rows.length)
            : math.max(0, constraints.maxHeight - 24).toDouble();
        return Padding(
          padding: const EdgeInsets.all(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _sheet(width, height)),
          ),
        );
      },
    );
  }

  Widget _records() {
    if (widget.rows.isEmpty) {
      final label = Text(
        widget.emptyLabel ?? 'No results'.tr,
        style: AppTextStyles.caption,
        textAlign: TextAlign.center,
      );
      if (widget.shrinkWrap) return Padding(padding: const EdgeInsets.all(24), child: label);
      return Center(child: label);
    }
    return ListView.separated(
      primary: widget.primary,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      itemCount: widget.rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _record(index),
    );
  }

  Widget _record(int index) {
    final cells = widget.rows[index];
    final actions = <int>[];
    final fields = <int>[];
    for (var i = 0; i < widget.columns.length; i++) {
      final column = widget.columns[i];
      if (column.fixed && column.center) {
        actions.add(i);
      } else {
        fields.add(i);
      }
    }
    final title = fields.isEmpty ? null : fields.first;
    final details = fields.skip(1);

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${index + 1}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Expanded(child: title == null ? const SizedBox.shrink() : _value(cells, title)),
                  for (final action in actions) ...[const SizedBox(width: 8), _value(cells, action)],
                ],
              ),
              for (final field in details)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 108,
                        child: Text(
                          widget.columns[field].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Expanded(child: _value(cells, field)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _value(List<Widget> cells, int index) {
    if (index >= cells.length) return const SizedBox.shrink();
    return cells[index];
  }

  Widget _sheet(double viewport, double height) {
    final minWidth = _columns.fold<double>(0, (sum, column) => sum + column.width);
    final tableWidth = math.max(viewport, minWidth);
    final scrolls = minWidth > viewport + 1;
    return Scrollbar(
      controller: _horizontal,
      thumbVisibility: scrolls,
      notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          height: height,
          child: Column(
            children: [
              _header(tableWidth),
              if (widget.shrinkWrap)
                widget.rows.isEmpty
                    ? SizedBox(
                        height: 72,
                        child: Center(child: Text(widget.emptyLabel ?? 'No results'.tr, style: AppTextStyles.caption)),
                      )
                    : Column(children: [for (var i = 0; i < widget.rows.length; i++) _row(i, tableWidth)])
              else
                Expanded(
                  child: widget.rows.isEmpty
                      ? Center(child: Text(widget.emptyLabel ?? 'No results'.tr, style: AppTextStyles.caption))
                      : ListView.builder(
                          primary: widget.primary,
                          itemCount: widget.rows.length,
                          itemBuilder: (context, index) => _row(index, tableWidth),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(double tableWidth) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(children: [for (var i = 0; i < _columns.length; i++) _cell(i, tableWidth, header: true)]),
      ),
    );
  }

  Widget _row(int index, double tableWidth) {
    final cells = [AppTableText('${index + 1}'), ...widget.rows[index]];
    return Material(
      color: index.isOdd ? AppColors.card : AppColors.white,
      child: InkWell(
        onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(index),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                for (var i = 0; i < _columns.length; i++)
                  _cell(i, tableWidth, child: i < cells.length ? cells[i] : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(int index, double tableWidth, {bool header = false, Widget? child}) {
    final column = _columns[index];
    final align = column.center ? Alignment.center : AlignmentDirectional.centerStart;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          end: index == _columns.length - 1 ? BorderSide.none : const BorderSide(color: AppColors.border),
        ),
      ),
      child: SizedBox(
        width: _width(index, tableWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: column.center ? 8 : 16),
          child: Align(
            alignment: align,
            child: header
                ? Text(
                    column.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: column.center ? TextAlign.center : TextAlign.start,
                    style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                  )
                : child,
          ),
        ),
      ),
    );
  }

  double _width(int index, double tableWidth) {
    final columns = _columns;
    final minWidth = columns.fold<double>(0, (sum, column) => sum + column.width);
    if (tableWidth <= minWidth) return columns[index].width;
    final flex = columns.fold<int>(0, (sum, column) => sum + (column.fixed ? 0 : math.max(column.flex, 1)));
    if (columns[index].fixed || flex == 0) return columns[index].width;
    final extra = tableWidth - minWidth;
    final share = math.max(columns[index].flex, 1);
    return columns[index].width + extra * share / flex;
  }
}

class AppTableText extends StatelessWidget {
  const AppTableText(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.body.copyWith(fontSize: 14));
  }
}
