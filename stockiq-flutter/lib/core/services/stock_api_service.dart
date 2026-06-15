import 'package:dio/dio.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/stock_model.dart';
import '../../shared/models/movement_model.dart';
import 'api_service.dart';

class StockApiService {
  final Dio _dio = ApiService.instance.client;

  // ── Produtos ──────────────────────────────────────────────────────────────

  Future<List<ProductModel>> getProducts({String? q}) async {
    try {
      final resp = await _dio.get('/products', queryParameters: q != null ? {'q': q} : null);
      return (resp.data as List).map((e) => ProductModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  Future<ProductModel> getProduct(String id) async {
    try {
      final resp = await _dio.get('/products/$id');
      return ProductModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  Future<ProductModel> createProduct(Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post('/products', data: data);
      return ProductModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  Future<ProductModel> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.patch('/products/$id', data: data);
      return ProductModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/products/$id');
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  /// Retorna base64 da imagem QR do produto
  Future<String> getProductQR(String productId) async {
    try {
      final resp = await _dio.get('/products/$productId/qr');
      return resp.data['qr_image'] as String;
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  /// Busca produto pelo payload do QR Code escaneado
  Future<ProductModel> scanQR(String qrPayload) async {
    try {
      final encoded = Uri.encodeComponent(qrPayload);
      final resp = await _dio.get('/products/scan/$encoded');
      return ProductModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  // ── Estoque ───────────────────────────────────────────────────────────────

  Future<List<StockModel>> getBranchStock(String branchId) async {
    try {
      final resp = await _dio.get('/branches/$branchId/stock');
      return (resp.data as List).map((e) => StockModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  Future<List<StockModel>> getLowStock() async {
    try {
      final resp = await _dio.get('/stock/low');
      return (resp.data as List).map((e) => StockModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  // ── Movimentações ──────────────────────────────────────────────────────────

  Future<List<MovementModel>> getMovements({int limit = 50}) async {
    try {
      final resp = await _dio.get('/movements', queryParameters: {'limit': limit});
      return (resp.data as List).map((e) => MovementModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  Future<MovementModel> registerMovement({
    required String type,
    required int quantity,
    required String productId,
    required String branchId,
    String? destBranchId,
    String? notes,
  }) async {
    try {
      final resp = await _dio.post('/movements', data: {
        'type': type,
        'quantity': quantity,
        'product_id': productId,
        'branch_id': branchId,
        if (destBranchId != null) 'dest_branch_id': destBranchId,
        if (notes != null) 'notes': notes,
      });
      return MovementModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  // ── IA ────────────────────────────────────────────────────────────────────

  Future<String> askAI(String question) async {
    try {
      final resp = await _dio.post('/ai/ask', data: {'question': question});
      return resp.data['answer'] as String;
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }
}
