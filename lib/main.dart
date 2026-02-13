/// Sellio Metrics Dashboard — Entry Point
library;

import 'package:flutter/material.dart';

import 'di/service_locator.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  runApp(const SellioMetricsApp());
}
