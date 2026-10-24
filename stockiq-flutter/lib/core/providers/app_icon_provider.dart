import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/widgets/app_icons.dart';

/// Ícone do app escolhido pela pessoa -- salvo só neste aparelho (é gosto
/// pessoal, não configuração da empresa), mesmo padrão do tema claro/escuro.
class AppIconNotifier extends StateNotifier<AppIconChoice> {
  static const _key = 'app_icon';

  AppIconNotifier() : super(AppIconChoice.fallback) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) state = AppIconChoice.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // valor corrompido: fica no padrão
    }
  }

  Future<void> set(AppIconChoice choice) async {
    state = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(choice.toJson()));
  }

  Future<void> reset() => set(AppIconChoice.fallback);
}

final appIconProvider = StateNotifierProvider<AppIconNotifier, AppIconChoice>((_) => AppIconNotifier());
