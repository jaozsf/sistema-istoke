import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_model.freezed.dart';
part 'product_model.g.dart';

double _priceFromJson(dynamic value) =>
    value is String ? double.parse(value) : (value as num).toDouble();

@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String sku,
    required String name,
    String? description,
    String? category,
    required String unit,
    @JsonKey(name: 'sale_price', fromJson: _priceFromJson) required double salePrice,
    @JsonKey(name: 'cost_price', fromJson: _priceFromJson) required double costPrice,
    @JsonKey(name: 'min_stock') required int minStock,
    @JsonKey(name: 'margin_percent') required double marginPercent,
    @JsonKey(name: 'qr_code') String? qrCode,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) => _$ProductModelFromJson(json);
}
