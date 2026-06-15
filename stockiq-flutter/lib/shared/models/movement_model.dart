import 'package:freezed_annotation/freezed_annotation.dart';

part 'movement_model.freezed.dart';
part 'movement_model.g.dart';

@freezed
class MovementModel with _$MovementModel {
  const factory MovementModel({
    required String id,
    required String type,
    required int quantity,
    String? notes,
    @JsonKey(name: 'product_id') required String productId,
    @JsonKey(name: 'branch_id') required String branchId,
    @JsonKey(name: 'user_id') String? userId,
    @JsonKey(name: 'dest_branch_id') String? destBranchId,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _MovementModel;

  factory MovementModel.fromJson(Map<String, dynamic> json) => _$MovementModelFromJson(json);
}

extension MovementModelX on MovementModel {
  bool get isEntrada  => type == 'entrada';
  bool get isSaida    => type == 'saida';
  bool get isTransfer => type == 'transfer';
}
