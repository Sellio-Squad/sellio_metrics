import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../constants/app_constants.dart';

@module
abstract class AppModule {
  @lazySingleton
  Dio get dio => Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
}
