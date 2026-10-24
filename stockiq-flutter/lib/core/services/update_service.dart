import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Versão deste build. Ao lançar atualização: suba aqui, no `version:` do
/// pubspec.yaml (mesmo número) e escreva as novidades em [whatsNew].
const appVersion = '1.1.0';

/// O que mudou nesta versão -- aparece no aviso de atualização.
const whatsNew = <String>[
  'Pedidos: vendedor → produção → expedição → distribuidora',
  'Conferência de caixas pela expedição',
  'Padrão de caixa por modelo de copo, com prévia 3D',
  'Novo visual no estilo iPhone, tema claro e escuro',
  'Sessão não cai mais quando o app fica fechado',
];

enum UpdateKind {
  /// Usuário já está na versão nova (abriu o app depois de atualizar):
  /// mostra as novidades uma vez.
  installed,

  /// Web: servidor já tem build mais novo que o carregado no navegador --
  /// oferece recarregar.
  available,
}

class UpdateInfo {
  final UpdateKind kind;
  final String version;
  const UpdateInfo(this.kind, this.version);
}

class UpdateService {
  static const _seenKey = 'last_seen_version';

  /// Chamado ao abrir o app (já logado). Prioriza "tem build novo no
  /// servidor" (web) porque, sem recarregar, as novidades nem estão ali.
  static Future<UpdateInfo?> check() async {
    if (kIsWeb) {
      final server = await _serverVersion();
      if (server != null && _isNewer(server, appVersion)) {
        return UpdateInfo(UpdateKind.available, server);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_seenKey) != appVersion) {
      return const UpdateInfo(UpdateKind.installed, appVersion);
    }
    return null;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey, appVersion);
  }

  /// version.json é gerado pelo `flutter build web` a partir do pubspec.
  /// Query string evita pegar a cópia em cache do navegador/CDN.
  static Future<String?> _serverVersion() async {
    try {
      final url = Uri.base.resolve('version.json').replace(
        queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final resp = await Dio(BaseOptions(receiveTimeout: const Duration(seconds: 8)))
          .getUri<Map<String, dynamic>>(url);
      return resp.data?['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String a, String b) {
    List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
