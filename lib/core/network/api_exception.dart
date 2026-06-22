/// A normalized error surfaced by [ApiClient] regardless of transport detail.
///
/// The backend returns a consistent envelope on failure:
/// `{ success: false, message: string, ... }` with an HTTP status code.
/// We map everything (Dio errors, timeouts, offline) into this type so the UI
/// only ever has to handle one shape.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Field-level validation errors, when the backend provides them.
  final List<String> details;

  /// True when the failure is connectivity-related (offline, timeout) rather
  /// than a server response — lets the UI offer a "retry" affordance.
  final bool isNetwork;

  const ApiException(
    this.message, {
    this.statusCode,
    this.details = const [],
    this.isNetwork = false,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
