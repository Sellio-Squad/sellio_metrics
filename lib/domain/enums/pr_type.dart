/// Sellio Metrics — PR Type Enum
///
/// Type-safe PR type classification derived from PR title patterns.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

enum PrType {
  feature('Feature', Colors.green),
  fix('Fix', Colors.red),
  refactor('Refactor', Colors.blue),
  chore('Chore', Colors.grey),
  docs('Docs', Colors.teal),
  ci('CI', Colors.orange),
  test('Test', Colors.purple),
  style('Style', Colors.pink),
  other('Other', Colors.blueGrey);

  final String label;
  final Color color;

  const PrType(this.label, this.color);

  /// Classify a PR type from its title using pattern matching.
  static PrType fromTitle(String title) {
    final lower = title.toLowerCase();
    for (final entry in PrTypePatterns.patterns.entries) {
      if (entry.value.hasMatch(lower)) {
        return PrType.values.firstWhere(
          (t) => t.name == entry.key,
          orElse: () => PrType.other,
        );
      }
    }
    return PrType.other;
  }
}
