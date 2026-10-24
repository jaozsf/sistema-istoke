import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/router.dart' show homeFor;
import '../../core/theme/app_theme.dart';

/// 404: "404" montado com blocos que caem e se encaixam (referência:
/// página de erro da Stack VC), na paleta Lagoon. Usado pra rota
/// inexistente e pra registro que não existe mais (pedido apagado etc.).
class NotFoundView extends ConsumerWidget {
  final String title;
  final String message;
  const NotFoundView({
    super.key,
    this.title = 'Página não encontrada',
    this.message = 'A página que você procura não existe ou foi movida.',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppTheme.abyss : const Color(0xFF0E3A42);
    return Container(
      color: bg,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final tile = math.min(56.0, (c.maxWidth - 64) / 11); // 3 dígitos x 3 + 2 vãos
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -.5)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(message,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 15, height: 1.35)),
                  ),
                  SizedBox(height: tile * 1.4),
                  _BlockDigits(tile: tile),
                  SizedBox(height: tile * 1.6),
                  _HomeButton(onTap: () => context.go(homeFor(ref.read(currentUserProvider)))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: NotFoundView());
}

// ── "404" em blocos ───────────────────────────────────────────────────────────

const _four = [
  [1, 0, 1],
  [1, 1, 1],
  [0, 0, 1],
];
const _zero = [
  [1, 1, 1],
  [1, 0, 1],
  [1, 1, 1],
];

// Tons Lagoon + branco, sorteados por posição (determinístico, sempre igual)
const _shades = [
  AppTheme.deep,
  AppTheme.lagoon,
  AppTheme.aqua,
  AppTheme.foam,
  Color(0xFF0B2F36),
  Color(0xFF2FB3A6),
  Color(0xFF7FE6D6),
];

class _BlockDigits extends StatefulWidget {
  final double tile;
  const _BlockDigits({required this.tile});

  @override
  State<_BlockDigits> createState() => _BlockDigitsState();
}

class _BlockDigitsState extends State<_BlockDigits> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    final digits = [_four, _zero, _four];
    var blockIndex = 0;
    final rng = math.Random(404);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var d = 0; d < digits.length; d++) ...[
          if (d > 0) SizedBox(width: t * .8),
          Column(
            children: [
              for (var r = 0; r < 3; r++)
                Row(
                  children: [
                    for (var c = 0; c < 3; c++)
                      Builder(builder: (_) {
                        final on = digits[d][r][c] == 1;
                        final color = _shades[rng.nextInt(_shades.length)];
                        if (!on) return SizedBox(width: t, height: t);
                        // Cada bloco cai do alto em sequência (escada por
                        // posição), com leve quique ao encaixar.
                        final start = (blockIndex++ * .035).clamp(0.0, .6);
                        final anim = CurvedAnimation(
                          parent: _ctrl,
                          curve: Interval(start, math.min(1, start + .4), curve: Curves.easeOutBack),
                        );
                        return AnimatedBuilder(
                          animation: anim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, (1 - anim.value) * -t * 4),
                            child: Opacity(opacity: anim.value.clamp(0, 1), child: child),
                          ),
                          child: Container(
                            width: t,
                            height: t,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [color, Color.lerp(color, Colors.black, .12)!],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HomeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HomeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      fontFamily: 'monospace',
    );
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            color: AppTheme.abyss,
            child: const Icon(CupertinoIcons.chevron_right, color: AppTheme.aqua, size: 18),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              color: AppTheme.abyss,
              // Tela estreita (iPhone SE): encolhe o texto em vez de estourar
              child: const FittedBox(fit: BoxFit.scaleDown, child: Text('VOLTAR AO INÍCIO', style: style)),
            ),
          ),
        ],
      ),
    );
  }
}
