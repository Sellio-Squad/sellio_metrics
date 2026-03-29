import 'package:hux/hux.dart';

enum SProgressSize { small, medium, large }

HuxProgressSize _toHux(SProgressSize s) => switch (s) {
  SProgressSize.small => HuxProgressSize.small,
  SProgressSize.medium => HuxProgressSize.medium,
  SProgressSize.large => HuxProgressSize.large,
};

class SProgress extends HuxProgress {
  SProgress({
    super.key,
    required super.value,
    SProgressSize size = SProgressSize.medium,
  }) : super(size: _toHux(size));
}
