import 'package:sellio_metrics/domain/entities/member_status_entity.dart';
import 'package:sellio_metrics/data/models/member/member_model.dart';

extension MemberModelMapper on MemberModel {
  MemberStatusEntity toEntity() {
    return MemberStatusEntity(
      developer: developer,
      avatarUrl: avatarUrl,
      isActive: isActive,
      lastActiveDate: lastActiveDate,
    );
  }
}
