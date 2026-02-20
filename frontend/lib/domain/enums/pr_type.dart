/// Sellio Metrics — PR Type Enum
///
/// Pure domain enum — no framework dependencies.
/// UI concerns (colors, icons) live in presentation extensions.
library;

import '../../core/constants/app_constants.dart';

enum PrType {
  feature('Feature'),
  fix('Fix'),
  refactor('Refactor'),
  chore('Chore'),
  docs('Docs'),
  ci('CI'),
  test('Test'),
  style('Style'),
  other('Other');

  final String label;

  const PrType(this.label);

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
