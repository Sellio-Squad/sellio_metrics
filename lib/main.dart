/// Sellio Metrics Dashboard — Main Entry Point
///
/// Bootstraps the Flutter web application.
library;

import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SellioMetricsApp());
}
