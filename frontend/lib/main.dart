library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'core/di/service_locator.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    // Log to your observability system
    debugPrint('Flutter error: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform error: $error');
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

  setupDependencies();
  runApp(const SellioMetricsApp());
}
