import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../../shared/models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final _auth    = FirebaseAuth.instance;
  final _storage = const FlutterSecureStorage();
  final _dio     = ApiService.instance.client;

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

  /// Login/cadastro com Google (web: popup). Conta nova é criada
  /// automaticamente pelo backend na primeira vez (role operator).
  Future<UserModel> signInWithGoogle() async {
    try {
      final credential = await _auth.signInWithPopup(GoogleAuthProvider());
      return await _exchangeToken(credential.user!);
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
    await _auth.signOut();
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.userKey);
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
String userModelToJson(UserModel u) =>
    '{"id":"${u.id}","firebase_uid":"${u.firebaseUid}","email":"${u.email}",'
    '"full_name":"${u.fullName}","role":"${u.role}","is_active":${u.isActive},'
    '"company_id":"${u.companyId}","branch_id":${u.branchId != null ? '"${u.branchId}"' : 'null'},'
    '"created_at":"${u.createdAt}"}';

UserModel userModelFromJson(String json) {
  return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
