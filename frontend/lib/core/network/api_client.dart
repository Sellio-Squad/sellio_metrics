import 'package:dio/dio.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

/// Thin wrapper around Dio that standardises logging, 
/// status-code checks, and error mapping.
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// GET with automatic logging + status check.
  Future<T> get<T>(
    String path, {
    String? tag,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic data)? parser,
  }) async {
    final resolvedTag = tag ?? path;
    appLogger.network(resolvedTag, 'GET', 
        Uri.parse(_dio.options.baseUrl + path));

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
      );

      _assertSuccess(response, resolvedTag);

      if (parser != null) return parser(response.data);
      return response.data as T;
    } on DioException catch (e) {
      throw _mapDioError(e, resolvedTag);
    }
  }

  /// POST with automatic logging + status check.
  Future<T> post<T>(
    String path, {
    String? tag,
    dynamic data,
    T Function(dynamic data)? parser,
  }) async {
    final resolvedTag = tag ?? path;
    appLogger.network(resolvedTag, 'POST', 
        Uri.parse(_dio.options.baseUrl + path));

    try {
      final response = await _dio.post(path, data: data);

      _assertSuccess(response, resolvedTag);

      if (parser != null) return parser(response.data);
      return response.data as T;
    } on DioException catch (e) {
      throw _mapDioError(e, resolvedTag);
    }
  }

  void _assertSuccess(Response response, String tag) {
    if (response.statusCode == null || 
        response.statusCode! < 200 || 
        response.statusCode! >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: '$tag failed: ${response.statusCode}',
        data: response.data,
      );
    }
  }

  Exception _mapDioError(DioException e, String tag) {
    return ApiException(
      statusCode: e.response?.statusCode,
      message: '$tag failed: ${e.message}',
      data: e.response?.data,
    );
  }
}

/// Unified API exception — replaces all those scattered Exception() calls.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiException({
    this.statusCode,
    required this.message,
    this.data,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => 
      statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
