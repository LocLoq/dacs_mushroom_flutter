enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  validation,
  server,
  invalidResponse,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.requestId,
    this.retryAfter,
    required this.kind,
  });
  final String message;
  final int? statusCode;
  final String? code, requestId;
  final ApiErrorKind kind;
  final Duration? retryAfter;
  int get status => statusCode ?? 0;
  bool get isConflict => status == 409;
  bool get isForbidden => status == 403;
  bool get isNetwork => status == 0;
  @override
  String toString() => message;
}
