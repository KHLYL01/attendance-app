import 'package:flutter/widgets.dart';

/// Centralised responsive breakpoints used throughout the app.
class Breakpoints {
  Breakpoints._();

  /// Below this width is considered mobile/phone.
  static const double mobile = 600;

  /// Between [mobile] and [desktop] is tablet.
  static const double tablet = 900;

  /// At or above this width we render the dedicated web/desktop layout.
  static const double desktop = 900;

  /// Wider screens get extra side padding/center column on top of desktop.
  static const double wide = 1280;
}

enum DeviceFormFactor { mobile, tablet, desktop, wide }

/// Extension that exposes responsive helpers without colliding with the ones
/// GetX already adds to [BuildContext] (e.g. `isTablet`, `isDesktop`).
extension BuildContextResponsive on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True when we should use the dedicated web/desktop layouts.
  bool get useWebLayout => screenWidth >= Breakpoints.desktop;

  /// True for the largest layouts where we add extra padding / 3-column grids.
  bool get isWide => screenWidth >= Breakpoints.wide;

  DeviceFormFactor get formFactor {
    if (screenWidth >= Breakpoints.wide) return DeviceFormFactor.wide;
    if (screenWidth >= Breakpoints.desktop) return DeviceFormFactor.desktop;
    if (screenWidth >= Breakpoints.mobile) return DeviceFormFactor.tablet;
    return DeviceFormFactor.mobile;
  }
}
