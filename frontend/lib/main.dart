
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    if (kDebugMode) {
      return ErrorWidget.withDetails(
        message: details.exceptionAsString(),
        error: details.exception is FlutterError ? details.exception as FlutterError : null,
      );
    }

    return Material(
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This section failed to load. Try navigating away and back.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  };

  runApp(const SellioMetricsApp());
}
