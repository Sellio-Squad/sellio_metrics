library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/di/service_locator.dart';
import 'app.dart';
import 'core/logging/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  setupDependencies();
  final logger = sl.get<AppLogger>();

  FlutterError.onError = (details) {
    logger.error('Flutter', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('Platform', error, stack);
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
