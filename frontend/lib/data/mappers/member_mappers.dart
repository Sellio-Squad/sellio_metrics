import '../../domain/entities/member_status_entity.dart';
import '../models/member_model.dart';

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
