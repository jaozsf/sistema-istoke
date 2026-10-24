import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../../shared/models/user_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

class AuthService {
  final _auth       = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();
  final _storage    = const FlutterSecureStorage();
  final _dio        = ApiService.instance.client;

  /// Liga a renovação automática no ApiService. Chamado uma vez no boot.
  /// [onExpired] roda só quando a renovação falha de vez.
  static void installSessionRefresh({required void Function() onExpired}) {
    final service = AuthService();
    ApiService.tokenRefresher = service.refreshSession;
    ApiService.onSessionExpired = onExpired;
  }

  /// JWT da API expirou (app ficou fechado), mas a sessão do Firebase
  /// continua salva no aparelho -- pega um ID token novo e troca por outro
  /// JWT, sem pedir login. Retorna null se não houver sessão Firebase.
  Future<String?> refreshSession() async {
    // No boot o Firebase restaura o usuário de forma assíncrona; currentUser
    // pode ainda estar null nos primeiros ms.
    final firebaseUser = _auth.currentUser ??
        await _auth.authStateChanges().first.timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (firebaseUser == null) return null;

    final idToken = await firebaseUser.getIdToken(true);
    // Dio "cru": não passa pelo interceptor (evita loop 401 -> refresh -> 401)
    final resp = await Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
    )).post('/auth/login', data: {'firebase_id_token': idToken});

    final token = resp.data['access_token'] as String;
    final user  = UserModel.fromJson(resp.data['user'] as Map<String, dynamic>);
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.userKey, value: userModelToJson(user));
    return token;
  }

  // ── Login ────────────────────────────────────────────────────────────────────

  Future<UserModel> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await _exchangeToken(credential.user!);
    } on FirebaseAuthException catch (e) {
      throw ApiException(
        statusCode: 401,
        message: _firebaseMessage(e.code),
      );
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  /// Login/cadastro com Google (web: popup; mobile: SDK nativo). Conta
  /// nova é criada automaticamente pelo backend na primeira vez.
  Future<UserModel> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Sem isso o Google pula a tela de escolha de conta e reloga
        // silenciosamente na última conta usada no navegador — mesmo
        // depois de "Sair" no app (sessão do Google no browser é
        // separada da nossa). Força sempre mostrar o seletor de conta.
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        final credential = await _auth.signInWithPopup(provider);
        return await _exchangeToken(credential.user!);
      }

      // Mobile: usa o SDK nativo do Google em vez de signInWithProvider
      // (Custom Tab) -- esse último quebra em muitos aparelhos com
      // "missing initial state" quando o navegador padrão particiona
      // storage entre origens durante o redirect do OAuth.
      await _googleSignIn.signOut(); // força mostrar o seletor de conta
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw ApiException(statusCode: 401, message: 'Login cancelado.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return await _exchangeToken(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      throw ApiException(
        statusCode: 401,
        message: e.code == 'popup-closed-by-user'
            ? 'Login cancelado.'
            : _firebaseMessage(e.code),
      );
    } on DioException catch (e) {
      throw parseApiError(e);
    }
  }

  /// Troca o ID Token do Firebase pelo JWT interno e persiste sessão.
  Future<UserModel> _exchangeToken(User firebaseUser) async {
    final idToken = await firebaseUser.getIdToken();

    final response = await _dio.post('/auth/login', data: {
      'firebase_id_token': idToken,
    });

    final token = response.data['access_token'] as String;
    final user  = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);

    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.userKey, value: userModelToJson(user));

    return user;
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (kIsWeb) {
      final token = await _storage.read(key: AppConstants.fcmTokenKey);
      if (token != null) {
        try {
          await _dio.delete('/users/me/fcm-token/$token');
        } catch (_) {}
      }
    } else {
      await NotificationService.instance.deleteTokenFromBackend();
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  /// Atualiza só o cache local (não mexe no token) -- usado depois de um
  /// PATCH que muda dado do usuário, tipo o nome.
  Future<void> updateCachedUser(UserModel user) async {
    await _storage.write(key: AppConstants.userKey, value: userModelToJson(user));
  }

  // ── Estado ───────────────────────────────────────────────────────────────────

  Future<bool> get isLoggedIn async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return token != null && _auth.currentUser != null;
  }

  Future<UserModel?> get currentUser async {
    final json = await _storage.read(key: AppConstants.userKey);
    if (json == null) return null;
    return userModelFromJson(json);
  }

  // ── Reset de senha ───────────────────────────────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _firebaseMessage(String code) => switch (code) {
    'user-not-found'    => 'E-mail não encontrado.',
    'wrong-password'    => 'Senha incorreta.',
    'invalid-email'     => 'E-mail inválido.',
    'user-disabled'     => 'Conta desativada.',
    'too-many-requests' => 'Muitas tentativas. Aguarde.',
    _                   => 'Erro ao fazer login. Tente novamente.',
  };
}

// Helpers de serialização (sem code gen extra)
String userModelToJson(UserModel u) => jsonEncode({
      'id': u.id,
      'firebase_uid': u.firebaseUid,
      'email': u.email,
      'full_name': u.fullName,
      'role': u.role,
      'is_active': u.isActive,
      'company_id': u.companyId,
      'branch_id': u.branchId,
      'created_at': u.createdAt,
    });

UserModel userModelFromJson(String json) {
  return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
