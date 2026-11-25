// The open engine stub's copy of the private engine's exception, without the
// gRPC detail it has no transport for.

/// Something the engine could not do.
class BegzarEngineException implements Exception {
  const BegzarEngineException(this.error, {this.stackTrace});

  factory BegzarEngineException.message(String message) =>
      BegzarEngineException(message);

  final Object error;
  final StackTrace? stackTrace;

  String get message => error is String ? error as String : error.toString();

  @override
  String toString() => stackTrace == null ? message : '$message\n$stackTrace';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BegzarEngineException &&
          other.error.toString() == error.toString();

  @override
  int get hashCode => Object.hash(error, stackTrace);
}
