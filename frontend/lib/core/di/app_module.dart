import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';

@module
abstract class AppModule {
  @lazySingleton
  Dio get dio => Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ));

  @lazySingleton
  ApiClient apiClient(Dio dio) => ApiClient(dio);
}
