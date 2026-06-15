import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> signIn(String email, String senha) async {
  try {
    // 1. Login no Firebase
    final userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: senha);

    // 2. Pegar ID TOKEN
    final idToken = await userCredential.user!.getIdToken();

    print("ID TOKEN: $idToken");

    // 3. Enviar pra sua API
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"firebase_id_token": idToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("JWT da API: ${data['access_token']}");
    } else {
      throw Exception("Erro na API: ${response.body}");
    }
  } catch (e) {
    print("Erro login: $e");
    rethrow;
  }
}
