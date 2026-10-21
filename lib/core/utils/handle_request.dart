import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:get/get.dart';

import '../../data/local/failures.dart';
import '../widgets/custom_snack_bar.dart';

Future<void> handleRequest<T>(
  Future<Either<Failure, T>> Function() request, {
  required FutureOr<void> Function(T data) onSuccess,
  required RxBool isLoading,
  required RxnString errMessage,
  String? successMessage,
  void Function()? onFailure,
}) async {
  try {
    isLoading.value = true;
    errMessage.value = null;
    final result = await request();
    await result.fold<Future<void>>(
      (failure) async {
        onFailure?.call();
        errMessage.value = failure.message;
        customSnackBar(title: 'Error'.tr, message: failure.message, isDone: false);
      },
      (data) async {
        await onSuccess(data);
        if (successMessage != null && (errMessage.value == null || errMessage.value!.isEmpty)) {
          customSnackBar(title: 'Done'.tr, message: successMessage);
        }
      },
    );
  } finally {
    isLoading.value = false;
  }
}
