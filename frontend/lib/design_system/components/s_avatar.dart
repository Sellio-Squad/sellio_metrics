library;

import 'package:hux/hux.dart';

enum SAvatarSize { small, medium, large }

HuxAvatarSize _toHux(SAvatarSize s) => switch (s) {
  SAvatarSize.small => HuxAvatarSize.small,
  SAvatarSize.medium => HuxAvatarSize.medium,
  SAvatarSize.large => HuxAvatarSize.large,
};

class SAvatar extends HuxAvatar {
  SAvatar({
    super.key,
    required super.name,
    super.imageUrl,
    super.assetImage,
    super.backgroundColor,
    super.useGradient = false,
    SAvatarSize size = SAvatarSize.medium,
  }) : super(size: _toHux(size));
}
