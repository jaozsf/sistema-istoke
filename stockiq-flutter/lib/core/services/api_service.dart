import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';

final _log = Logger();

class ApiService {
  static ApiService? _instance;
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  ApiService._() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Interceptor: injeta JWT em todas as requisições autenticadas
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          _log.d('[API] ${options.method} ${options.path}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _log.d('[API] ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          _log.e('[API] Error: ${error.response?.statusCode} ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Dio get client => dio;
}

// ── Helpers tipados ────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

ApiException parseApiError(DioException e) {
  final code = e.response?.statusCode ?? 0;
  final detail = e.response?.data?['detail'];
  final msg = detail is String
      ? detail
      : detail is List
          ? (detail.first['msg'] ?? 'Erro desconhecido')
          : 'Erro de conexão';
  return ApiException(statusCode: code, message: msg);
}
