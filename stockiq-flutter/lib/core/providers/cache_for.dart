import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

extension CacheFor on AutoDisposeRef<Object?> {
  /// Mantém o resultado vivo por [duration] depois que nenhuma tela usa
  /// mais -- voltar pra tela não refaz a requisição, mas a memória é
  /// liberada sozinha depois (em vez de acumular até fechar o app).
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
