import 'package:dio/dio.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/stock_model.dart';
import '../../shared/models/movement_model.dart';
import '../../shared/models/finance_summary.dart';
import '../../shared/models/user_model.dart';
import 'api_service.dart';

class StockApiService {
  final Dio _dio = ApiService.instance.client;

  // ── Usuários (equipe) ────────────────────────────────────────────────────

  /// Lista os usuários da empresa (role mínimo: manager).
  Future<List<UserModel>> getUsers() async {
    try {
      final resp = await _dio.get('/users');
      return (resp.data as List).map((e) => UserModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  /// Cadastra uma pessoa nova por email (role mínimo: admin). Ela ainda não
  /// tem firebase_uid — vincula sozinho no primeiro login dela.
  Future<UserModel> createUser({
    required String email,
    required String fullName,
    required String role,
  }) async {
    try {
      final resp = await _dio.post('/users', data: {
        'email': email,
        'full_name': fullName,
        'role': role,
        // company_id/branch_id são ignorados pelo backend — sempre usa os
        // do admin que tá criando.
        'company_id': '',
      });
      return UserModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  /// Troca o cargo de alguém (role mínimo: admin).
  Future<UserModel> updateUserRole(String userId, String role) async {
    try {
      final resp = await _dio.patch('/users/$userId', data: {'role': role});
      return UserModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

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

  /// Baixa PDF com etiqueta QR Code (nome + SKU + QR) de cada produto ativo
  Future<List<int>> getQrLabelsPdf() async {
    try {
      final resp = await _dio.get<List<int>>(
        '/products/qr-labels/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return resp.data!;
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
    bool hasArt = false,
    bool hasBorder = false,
  }) async {
    try {
      final resp = await _dio.post('/movements', data: {
        'type': type,
        'quantity': quantity,
        'product_id': productId,
        'branch_id': branchId,
        if (destBranchId != null) 'dest_branch_id': destBranchId,
        if (notes != null) 'notes': notes,
        'has_art': hasArt,
        'has_border': hasBorder,
      });
      return MovementModel.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  // ── Financeiro ────────────────────────────────────────────────────────────

  Future<FinanceSummary> getFinanceSummary({int days = 1}) async {
    try {
      final resp = await _dio.get('/finance/summary', queryParameters: {'days': days});
      return FinanceSummary.fromJson(resp.data);
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  // ── Relatórios ────────────────────────────────────────────────────────────

  /// Baixa PDF do relatório executivo completo (alertas, saúde de filial, previsão)
  Future<List<int>> getExecutiveReportPdf() async {
    try {
      final resp = await _dio.get<List<int>>(
        '/analytics/report/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      return resp.data!;
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
