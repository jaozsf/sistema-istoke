import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_icon_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icons.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';

Future<void> showIconPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _IconPicker(),
  );
}

class _IconPicker extends ConsumerStatefulWidget {
  const _IconPicker();

  @override
  ConsumerState<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends ConsumerState<_IconPicker> {
  late AppIconChoice _draft = ref.read(appIconProvider);
  late IconKind _tab = _draft.kind;

  void _pick(AppIconChoice c) {
    Haptics.tap();
    setState(() => _draft = c);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accentOf(context);

    Widget option({required bool selected, required Widget child, required VoidCallback onTap, String? tooltip}) {
      final tile = GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? accent : Colors.transparent, width: 2.5),
          ),
          child: child,
        ),
      );
      return tooltip == null ? tile : Tooltip(message: tooltip, child: tile);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      minChildSize: .5,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Ícone do app', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Escolha o seu. Fica salvo só neste aparelho.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),

          // Prévia
          Center(
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('${_draft.kind}-${_draft.value}-${_draft.colorId}'),
                  tween: Tween(begin: .85, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: AppIconView(choice: _draft, size: 96),
                ),
                const SizedBox(height: 10),
                const BrandWordmark(size: 20),
              ],
            ),
          ),
          const SizedBox(height: 22),

          CupertinoSlidingSegmentedControl<IconKind>(
            groupValue: _tab,
            thumbColor: theme.colorScheme.surface,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            children: const {
              IconKind.glyph: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Desenhos')),
              IconKind.emoji: Text('Emojis'),
            },
            onValueChanged: (k) => setState(() => _tab = k ?? _tab),
          ),
          const SizedBox(height: 16),

          if (_tab == IconKind.glyph)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in iconGlyphs)
                  option(
                    tooltip: g.label,
                    selected: _draft.kind == IconKind.glyph && _draft.value == g.id,
                    onTap: () => _pick(_draft.copyWith(kind: IconKind.glyph, value: g.id)),
                    child: AppIconView(
                      choice: AppIconChoice(kind: IconKind.glyph, value: g.id, colorId: _draft.colorId),
                      size: 56,
                    ),
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in iconEmojis)
                  option(
                    selected: _draft.kind == IconKind.emoji && _draft.value == e,
                    onTap: () => _pick(_draft.copyWith(kind: IconKind.emoji, value: e)),
                    child: AppIconView(
                      choice: AppIconChoice(kind: IconKind.emoji, value: e, colorId: _draft.colorId),
                      size: 56,
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 22),
          Text('COR DE FUNDO', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in iconColors)
                option(
                  tooltip: c.label,
                  selected: _draft.colorId == c.id,
                  onTap: () => _pick(_draft.copyWith(colorId: c.id)),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () async {
              await ref.read(appIconProvider.notifier).set(_draft);
              if (!context.mounted) return;
              Navigator.pop(context);
              showIosToast(context, 'Ícone atualizado');
            },
            child: const Text('Usar este ícone'),
          ),
          TextButton(
            onPressed: () => _pick(AppIconChoice.fallback),
            child: const Text('Voltar ao padrão'),
          ),
        ],
      ),
    );
  }
}
