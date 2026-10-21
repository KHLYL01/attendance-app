abstract class Failure {
  final String message;

  const Failure(this.message);
}

/// A database or file error. The message is a translation key or a ready sentence.
class LocalFailure extends Failure implements Exception {
  const LocalFailure(super.message);

  @override
  String toString() => message;
}
