import 'package:dartz/dartz.dart';

import '../../data/local/failures.dart';

/// Runs a local (database or file) operation and turns any exception into a [Failure].
Future<Either<Failure, T>> handleLocal<T>(Future<T> Function() request) async {
  try {
    return Right(await request());
  } on LocalFailure catch (e) {
    return Left(e);
  } catch (e) {
    return Left(LocalFailure(e.toString()));
  }
}
