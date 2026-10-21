import 'package:flutter/material.dart';
import 'package:get/get.dart';

// import 'package:get/instance_manager.dart';

extension CustomWidget on Widget {
  Widget center() {
    return Center(child: this);
  }

  Widget expanded({int flex = 1}) {
    return Expanded(flex: flex, child: this);
  }

  Widget padding(EdgeInsetsGeometry? padding) {
    return Padding(padding: padding ?? const EdgeInsets.all(8), child: this);
  }

  Widget paddingDirectional(EdgeInsetsDirectional? padding) {
    return Padding(padding: padding ?? const EdgeInsetsDirectional.all(8), child: this);
  }

  Widget paddingSymmetricWidth16() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Get.context!.width / 14),
      child: this,
    );
  }

  Widget paddingSymmetricWidth24() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Get.context!.width / 24),
      child: this,
    );
  }

  Widget paddingSymmetricWidth32() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Get.context!.width / 32),
      child: this,
    );
  }

  Widget makeSafeArea() {
    return SafeArea(child: this);
  }

  Widget align({required AlignmentGeometry alignment}) {
    return Align(alignment: alignment, child: this);
  }

  Widget fittedBox() {
    return FittedBox(child: this);
  }

  Widget onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }

  Widget onDoubleTap(VoidCallback onDoubleTap) {
    return GestureDetector(onDoubleTap: onDoubleTap, child: this);
  }

  Widget scrollDirection(Axis scrollDirection) {
    return SingleChildScrollView(scrollDirection: scrollDirection, child: this);
  }

  Widget onLongPress(VoidCallback onLongPress) {
    return GestureDetector(onLongPress: onLongPress, child: this);
  }
}
