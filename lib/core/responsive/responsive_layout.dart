import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Picks the appropriate widget based on screen width.
///
/// Use this at the top of any "page" route to switch between the original
/// mobile design and the dedicated web/desktop design without touching the
/// underlying controllers or business logic.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({super.key, required this.mobile, required this.web, this.tablet});

  /// Builder for the mobile (and default) experience.
  final WidgetBuilder mobile;

  /// Builder for the web/desktop experience (>= [Breakpoints.desktop]).
  final WidgetBuilder web;

  /// Optional tablet override. Falls back to [mobile] when not provided.
  final WidgetBuilder? tablet;

  @override
  Widget build(BuildContext context) {
    final width = context.screenWidth;
    if (width >= Breakpoints.desktop) {
      return web(context);
    }
    if (width >= Breakpoints.mobile && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}
