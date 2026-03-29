import 'package:hux/hux.dart';

enum SLoadingSize { small, medium, large, extraLarge }

HuxLoadingSize _toHux(SLoadingSize s) => switch (s) {
  SLoadingSize.small => HuxLoadingSize.small,
  SLoadingSize.medium => HuxLoadingSize.medium,
  SLoadingSize.large => HuxLoadingSize.large,
  SLoadingSize.extraLarge => HuxLoadingSize.extraLarge,
};

class SLoading extends HuxLoading {
  SLoading({super.key, SLoadingSize size = SLoadingSize.medium})
    : super(size: _toHux(size));
}
