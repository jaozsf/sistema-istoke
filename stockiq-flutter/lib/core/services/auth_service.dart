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
      // 1. Autentica no Firebase
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Pega o ID Token do Firebase
      final idToken = await credential.user!.getIdToken();

      // 3. Troca pelo JWT interno do backend
      final response = await _dio.post('/auth/login', data: {
        'firebase_id_token': idToken,
      });

      final token = response.data['access_token'] as String;
      final user  = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);

      // 4. Persiste token e user
      await _storage.write(key: AppConstants.tokenKey, value: token);
      await _storage.write(key: AppConstants.userKey, value: userModelToJson(user));

      return user;
    } on FirebaseAuthException catch (e) {
      throw ApiException(
        statusCode: 401,
        message: _firebaseMessage(e.code),
      );
    } on DioException catch (e) {
      throw parseApiError(e);
    }
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
  // Usa UserModel.fromJson via dart:convert
  import 'dart:convert';
  return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
}
