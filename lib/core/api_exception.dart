import 'package:dio/dio.dart';

/// An error from the backend, read from the `error` object of its response.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;

  /// Validation errors keyed by request field, e.g. {"email": "must be a well-formed email address"}.
  final Map<String, String> fieldErrors;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException('Cannot reach the server. Check your connection.');
    }
    final data = response.data;
    final error = data is Map<String, dynamic> ? data['error'] : null;
    if (error is Map<String, dynamic>) {
      final errors = <String, String>{};
      final details = error['details'];
      if (details is Map) {
        details.forEach((key, value) => errors['$key'] = '$value');
      }
      final message = error['message'] as String?;
      return ApiException(
        message ?? 'Something went wrong (${response.statusCode})',
        statusCode: response.statusCode,
        fieldErrors: errors,
      );
    }
    return ApiException('Something went wrong (${response.statusCode})', statusCode: response.statusCode);
  }

  @override
  String toString() => message;
}
