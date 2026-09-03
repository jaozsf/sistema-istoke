import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Entrada padrão (fade + subida leve) usada em cards/itens de lista em
/// todo o app -- um padrão só, escalonado pelo índice do item, em vez de
/// cada tela inventar uma animação diferente.
extension EntranceAnimation on Widget {
  Widget entrance({int index = 0}) {
    final delay = Duration(milliseconds: 30 * index.clamp(0, 10));
    return animate()
        .fadeIn(duration: 200.ms, delay: delay)
        .slideY(begin: 0.08, end: 0, duration: 200.ms, delay: delay, curve: Curves.easeOut);
  }
}
