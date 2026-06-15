import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    @JsonKey(name: 'firebase_uid') required String firebaseUid,
    required String email,
    @JsonKey(name: 'full_name') required String fullName,
    required String role,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'branch_id') String? branchId,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}

extension UserModelX on UserModel {
  bool get isAdmin   => role == 'admin';
  bool get isManager => role == 'admin' || role == 'manager';
}
