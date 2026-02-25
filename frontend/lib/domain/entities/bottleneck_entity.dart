library;

import '../../domain/enums/severity.dart';

class BottleneckEntity {
  final int prNumber;
  final String title;
  final String url;
  final String author;
  final double waitTimeHours;
  final double waitTimeDays;
  final Severity severity;

  const BottleneckEntity({
    required this.prNumber,
    required this.title,
    required this.url,
    required this.author,
    required this.waitTimeHours,
    required this.waitTimeDays,
    required this.severity,
  });
}
