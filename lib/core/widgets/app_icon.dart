import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constant/app_colors.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.asset, {
    super.key,
    this.size = 22,
    this.color,
    this.recolor = true,
    this.matchTextDirection = false,
  });

  final String asset;
  final double size;
  final Color? color;
  final bool recolor;
  final bool matchTextDirection;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      matchTextDirection: matchTextDirection,
      colorFilter: recolor ? ColorFilter.mode(color ?? AppColors.primary, BlendMode.srcIn) : null,
    );
  }
}
