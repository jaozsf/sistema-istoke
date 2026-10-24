import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/services/app_reload.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import 'app_widgets.dart';
import 'ios_widgets.dart';

/// Envolve o shell logado: na primeira montagem checa se houve atualização
/// e mostra o aviso "olá, temos uma nova atualização para você :)".
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  // Uma vez por abertura do app, mesmo que o shell remonte
  static bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final info = await UpdateService.check();
    if (info == null || !mounted) return;
    // Pequena pausa: deixa a primeira tela aparecer antes do aviso subir
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Haptics.success();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => UpdateSheet(info: info),
    );
    if (info.kind == UpdateKind.installed) await UpdateService.markSeen();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UpdateSheet extends StatelessWidget {
  final UpdateInfo info;
  const UpdateSheet({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = info.kind == UpdateKind.available;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .5, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppTheme.lagoon.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Olá, temos uma nova atualização para você :)',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandWordmark(size: 15),
              Text('  versão ${info.version}', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 20),
          if (!available)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (final item in whatsNew)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: AppTheme.accentOf(context)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else
            Text(
              'Recarregue pra usar a versão mais nova.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (available) reloadApp();
            },
            child: Text(available ? 'Atualizar agora' : 'Vamos lá'),
          ),
          if (available)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Depois')),
        ],
      ),
    );
  }
}
