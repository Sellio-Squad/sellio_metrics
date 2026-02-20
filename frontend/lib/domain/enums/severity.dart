/// Sellio Metrics — Severity Enum
///
/// Type-safe severity levels for bottleneck analysis.
library;

enum Severity {
  low,
  medium,
  high;

  /// Human-readable label.
  String get label => name.toUpperCase();
}
