import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';

final _log = Logger();

class ApiService {
  static ApiService? _instance;
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  /// Troca a sessão do Firebase (que fica salva no aparelho por meses) por
  /// um JWT novo da API. Setado pelo AuthService -- callback em vez de
  /// import pra não criar ciclo api_service <-> auth_service.
  static Future<String?> Function()? tokenRefresher;

  /// Chamado quando nem a renovação funcionou (conta removida do Firebase,
  /// desativada etc.) -- aí sim manda pro login.
  static void Function()? onSessionExpired;

  Completer<String?>? _refreshing;

  ApiService._() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

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
        onError: (error, handler) async {
          final req = error.requestOptions;
          final status = error.response?.statusCode;
          _log.e('[API] Error: $status ${error.message}');

          // 1) JWT expirou com o app fechado -> renova em silêncio e repete
          //    a requisição uma vez, em vez de derrubar a sessão.
          final isAuthCall = req.path.contains('/auth/login');
          if (status == 401 && !isAuthCall && req.extra['retried_auth'] != true) {
            final newToken = await _refreshToken();
            if (newToken != null) {
              req.extra['retried_auth'] = true;
              req.headers['Authorization'] = 'Bearer $newToken';
              try {
                return handler.resolve(await dio.fetch(req));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            onSessionExpired?.call();
          }

          // 2) Cold start da Vercel estourou o timeout -> tenta de novo uma
          //    vez (a segunda já pega a instância quente).
          final isTimeout = error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError;
          if (isTimeout && req.extra['retried_net'] != true) {
            req.extra['retried_net'] = true;
            try {
              return handler.resolve(await dio.fetch(req));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Uma renovação por vez -- várias telas recebendo 401 juntas esperam a
  /// mesma troca de token em vez de disparar N logins.
  Future<String?> _refreshToken() async {
    if (_refreshing != null) return _refreshing!.future;
    final refresher = tokenRefresher;
    if (refresher == null) return null;
    final completer = _refreshing = Completer<String?>();
    try {
      final token = await refresher();
      completer.complete(token);
      return token;
    } catch (e) {
      _log.w('[API] Renovação de sessão falhou: $e');
      completer.complete(null);
      return null;
    } finally {
      _refreshing = null;
    }
  }

  static ApiService get instance {
    _instance ??= ApiService._();
    return _instance!;
  }

  Dio get client => dio;

  /// Acorda a função serverless + banco enquanto a splash/login aparece,
  /// pra primeira tela de verdade não pagar o cold start.
  Future<void> warmUp() async {
    try {
      final root = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '');
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)))
          .get('$root/health/db');
    } catch (_) {}
  }
}

// ── Helpers tipados ────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}

ApiException parseApiError(DioException e) {
  final code = e.response?.statusCode ?? 0;
  final data = e.response?.data;
  final detail = data is Map ? data['detail'] : null;
  final msg = detail is String
      ? detail
      : detail is List && detail.isNotEmpty
          ? (detail.first['msg'] ?? 'Erro desconhecido')
          : switch (e.type) {
              DioExceptionType.connectionTimeout ||
              DioExceptionType.receiveTimeout => 'Servidor demorou a responder. Tente de novo.',
              DioExceptionType.connectionError => 'Sem conexão com o servidor. Verifique a internet.',
              _ => code >= 500 ? 'Erro no servidor ($code). Tente de novo.' : 'Erro de conexão',
            };
  return ApiException(statusCode: code, message: msg);
}
