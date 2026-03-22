import 'package:dio/dio.dart';

class AppNetworkException implements Exception {
  final String message;
  final int? statusCode;

  AppNetworkException(this.message, {this.statusCode});

  factory AppNetworkException.fromDio(DioException e) {
    final message = e.response?.data?['error'] ?? 
                    e.response?.data?['message'] ?? 
                    e.message ?? 
                    'An unexpected network error occurred';
    return AppNetworkException(message, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => message;
}

Future<T> safeApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw AppNetworkException.fromDio(e);
  } catch (e) {
    if (e is AppNetworkException) rethrow;
    throw AppNetworkException('An unexpected error occurred: $e');
  }
}
