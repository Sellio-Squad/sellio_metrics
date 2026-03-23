
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/di/injection.dart';
import 'package:sellio_metrics/core/constants/app_constants.dart';
import 'package:sellio_metrics/app.dart';
import 'package:sellio_metrics/core/logging/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  configureDependencies(ApiConfig.useFakeData ? Environment.dev : Environment.prod);

  FlutterError.onError = (details) {
    appLogger.error('Flutter', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    appLogger.error('Platform', error, stack);
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const Center(
      child: Text(
        "Something went wrong",
        style: TextStyle(color: Colors.red),
      ),
    );
  };

  runApp(const SellioMetricsApp());
}
