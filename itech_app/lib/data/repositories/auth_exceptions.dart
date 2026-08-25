import 'package:flutter/foundation.dart';

/// Thrown by repository reads that require an authenticated session but
/// were called while signed out.
///
/// Callers can distinguish this from "the query legitimately returned no
/// rows" — previously the repositories returned empty lists/streams for
/// both cases, which made "my data disappeared" impossible to tell apart
/// from "I got logged out".
@immutable
class NotSignedInException implements Exception {
  const NotSignedInException(this.operation);

  /// Name of the repository operation that required a session.
  final String operation;

  @override
  String toString() =>
      'NotSignedInException: $operation requires a signed-in user.';
}
