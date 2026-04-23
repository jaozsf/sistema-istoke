import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_model.freezed.dart';
part 'stock_model.g.dart';

@freezed
class StockModel with _$StockModel {
  const factory StockModel({
    required String id,
    @JsonKey(name: 'product_id') required String productId,
    @JsonKey(name: 'branch_id') required String branchId,
    required int quantity,
    @JsonKey(name: 'min_quantity') required int minQuantity,
    @JsonKey(name: 'is_low') required bool isLow,
    @JsonKey(name: 'updated_at') required String updatedAt,
  }) = _StockModel;

  factory StockModel.fromJson(Map<String, dynamic> json) => _$StockModelFromJson(json);
}
