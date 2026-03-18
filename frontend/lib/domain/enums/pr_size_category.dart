/// PR Size Category — Domain Enum
///
/// Classifies PR size by total lines changed (additions + deletions).
/// Thresholds based on industry best practices for review efficiency.
library;

enum PrSizeCategory {
  xs(label: 'XS', maxLines: 10),
  s(label: 'S', maxLines: 100),
  m(label: 'M', maxLines: 400),
  l(label: 'L', maxLines: 1000),
  xl(label: 'XL', maxLines: double.maxFinite ~/ 1);

  final String label;
  final int maxLines;

  const PrSizeCategory({required this.label, required this.maxLines});

  static PrSizeCategory fromTotalChanges(int total) {
    if (total <= PrSizeCategory.xs.maxLines) return PrSizeCategory.xs;
    if (total <= PrSizeCategory.s.maxLines) return PrSizeCategory.s;
    if (total <= PrSizeCategory.m.maxLines) return PrSizeCategory.m;
    if (total <= PrSizeCategory.l.maxLines) return PrSizeCategory.l;
    return PrSizeCategory.xl;
  }

  bool get isLarge => this == PrSizeCategory.l || this == PrSizeCategory.xl;
}
