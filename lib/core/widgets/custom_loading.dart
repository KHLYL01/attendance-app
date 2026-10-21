import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../constant/app_colors.dart';
import '../extensions/widget_extension.dart';

enum LoadingStyle {
  /// Centered pulse dots (web) or spinner (mobile).
  spinner,

  /// Skeleton list rows — ideal for panels and tables.
  list,

  /// Skeleton table rows.
  table,

  /// Skeleton KPI cards row.
  kpi,

  /// Skeleton analysis grid.
  analysis,

  /// Skeleton expense grid.
  expense,

  /// Full panel skeleton with header + rows.
  panel,
}

class CustomLoading extends StatelessWidget {
  const CustomLoading({super.key, this.style = LoadingStyle.spinner, this.skeletonCount});

  final LoadingStyle style;
  final int? skeletonCount;

  @override
  Widget build(BuildContext context) {
    if (style == LoadingStyle.spinner) {
      return const SpinKitThreeInOut(color: AppColors.secondary).center();
    }
    final count = skeletonCount ?? 6;
    return _Shimmer(
      child: switch (style) {
        LoadingStyle.spinner => const SizedBox.shrink(),
        LoadingStyle.list => _rows(count, height: 76, radius: 14),
        LoadingStyle.table => _table(count),
        LoadingStyle.kpi => _grid(count: 4, aspect: 2.2),
        LoadingStyle.analysis => _analysis(),
        LoadingStyle.expense => _grid(count: 4, aspect: 1.4),
        LoadingStyle.panel => _panel(),
      },
    );
  }

  Widget _rows(int count, {required double height, required double radius}) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _Bone(height: height, radius: radius),
        ],
      ],
    );
  }

  Widget _table(int count) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _Bone(height: 44, radius: 10),
        const SizedBox(height: 8),
        for (var i = 0; i < count; i++) ...[if (i > 0) const SizedBox(height: 6), const _Bone(height: 48, radius: 8)],
      ],
    );
  }

  Widget _grid({required int count, required double aspect, bool pad = true}) {
    return GridView.count(
      padding: pad ? const EdgeInsets.all(16) : EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspect,
      children: [for (var i = 0; i < count; i++) const _Bone(radius: 16)],
    );
  }

  Widget _analysis() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _grid(count: 6, aspect: 1.65, pad: false),
        const SizedBox(height: 16),
        const _Bone(height: 220, radius: 16),
        const SizedBox(height: 12),
        const _Bone(height: 180, radius: 16),
      ],
    );
  }

  Widget _panel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _Bone(height: 168, radius: 18),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: _Bone(height: 72, radius: 14)),
            SizedBox(width: 12),
            Expanded(child: _Bone(height: 72, radius: 14)),
          ],
        ),
        const SizedBox(height: 16),
        const _Bone(height: 64, radius: 14),
        const SizedBox(height: 10),
        const _Bone(height: 18, radius: 6),
        const SizedBox(height: 8),
        const _Bone(height: 18, radius: 6),
      ],
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.4 + (2.8 * slide), 0),
              end: Alignment(-0.2 + (2.8 * slide), 0),
              colors: const [AppColors.border, AppColors.primarySoft, AppColors.border],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({this.height, this.radius = 12});

  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}
