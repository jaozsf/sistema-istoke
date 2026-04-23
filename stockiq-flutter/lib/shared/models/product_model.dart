import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String sku,
    required String name,
    String? description,
    String? category,
    required String unit,
    @JsonKey(name: 'sale_price') required double salePrice,
    @JsonKey(name: 'cost_price') required double costPrice,
    @JsonKey(name: 'min_stock') required int minStock,
    @JsonKey(name: 'margin_percent') required double marginPercent,
    @JsonKey(name: 'qr_code') String? qrCode,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) => _$ProductModelFromJson(json);
}
