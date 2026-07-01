/// PR Code Insight — Domain Entity
///
/// Represents a single insight extracted from PR analysis.
/// Designed for extensibility: future AI-generated insights use the same model.
library;

enum PrInsightSeverity { info, warning, tip }

class PrCodeInsight {
  final String category;
  final String message;
  final PrInsightSeverity severity;

  const PrCodeInsight({
    required this.category,
    required this.message,
    required this.severity,
  });
}
