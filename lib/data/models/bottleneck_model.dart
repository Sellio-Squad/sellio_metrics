/// Sellio Metrics — Bottleneck Model
library;

class BottleneckModel {
  final int prNumber;
  final String title;
  final String url;
  final String author;
  final double waitTimeHours;
  final double waitTimeDays;
  final String severity; // 'low', 'medium', 'high'

  const BottleneckModel({
    required this.prNumber,
    required this.title,
    required this.url,
    required this.author,
    required this.waitTimeHours,
    required this.waitTimeDays,
    required this.severity,
  });
}
