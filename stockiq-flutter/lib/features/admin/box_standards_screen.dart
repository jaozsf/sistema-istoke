import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';

/// Um padrão de caixa por modelo de copo. Vendedor pede em caixas; a
/// expedição confere caixa a caixa; peso/medidas viram volumes e peso da
/// carga pra distribuidora.
class BoxStandardsScreen extends ConsumerWidget {
  const BoxStandardsScreen({super.key});

  void _edit(BuildContext context, ProductModel p, BoxStandard? box, bool canEdit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BoxEditor(product: p, existing: box, canEdit: canEdit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final products = ref.watch(productsProvider(null));
    final boxes = ref.watch(boxStandardsProvider);

    return IosPage(
      title: 'Padrões de caixa',
      onRefresh: () async {
        ref.invalidate(boxStandardsProvider);
        ref.invalidate(productsProvider);
      },
      slivers: [
        products.when(
          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator())),
          error: (e, _) => SliverToBoxAdapter(child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(productsProvider))),
          data: (all) {
            final map = boxes.valueOrNull ?? {};
            final active = all.where((p) => p.isActive).toList();
            final missing = active.where((p) => !map.containsKey(p.id)).toList();
            final done = active.where((p) => map.containsKey(p.id)).toList();
            return SliverToBoxAdapter(
              child: Column(
                children: [
                  if (missing.isNotEmpty)
                    IosSection(
                      header: 'Sem padrão (${missing.length})',
                      footer: 'Esses modelos não podem ser pedidos até ter padrão de caixa.',
                      children: [
                        for (final p in missing)
                          IosTile(
                            icon: CupertinoIcons.exclamationmark_triangle_fill,
                            iconColor: AppTheme.warning,
                            title: p.name,
                            subtitle: p.sku,
                            onTap: isAdmin ? () => _edit(context, p, null, true) : null,
                          ),
                      ],
                    ),
                  if (done.isNotEmpty)
                    IosSection(
                      header: 'Configurados (${done.length})',
                      children: [
                        for (final p in done)
                          Builder(builder: (_) {
                            final b = map[p.id]!;
                            final dims = b.hasDimensions
                                ? '${_n(b.lengthCm)}×${_n(b.widthCm)}×${_n(b.heightCm)} cm'
                                : null;
                            return IosTile(
                              leading: SizedBox(
                                width: 34,
                                height: 34,
                                child: b.hasDimensions
                                    ? Box3D(length: b.lengthCm!, width: b.widthCm!, height: b.heightCm!, size: 34)
                                    : const IconBadge(icon: CupertinoIcons.cube_box_fill, color: AppTheme.lagoon),
                              ),
                              title: p.name,
                              subtitle: [
                                '${b.unitsPerBox} un/cx',
                                if (dims != null) dims,
                                if (b.weightKg != null) '${_n(b.weightKg)} kg',
                              ].join(' · '),
                              onTap: () => _edit(context, p, b, isAdmin),
                            );
                          }),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

String _n(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _BoxEditor extends ConsumerStatefulWidget {
  final ProductModel product;
  final BoxStandard? existing;
  final bool canEdit;
  const _BoxEditor({required this.product, this.existing, required this.canEdit});

  @override
  ConsumerState<_BoxEditor> createState() => _BoxEditorState();
}

class _BoxEditorState extends ConsumerState<_BoxEditor> {
  late final _units = TextEditingController(text: widget.existing?.unitsPerBox.toString() ?? '');
  late final _type = TextEditingController(text: widget.existing?.boxType);
  late final _l = TextEditingController(text: _n(widget.existing?.lengthCm));
  late final _w = TextEditingController(text: _n(widget.existing?.widthCm));
  late final _h = TextEditingController(text: _n(widget.existing?.heightCm));
  late final _kg = TextEditingController(text: _n(widget.existing?.weightKg));
  late final _notes = TextEditingController(text: widget.existing?.notes);
  bool _saving = false;

  double? _d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  Future<void> _save() async {
    final units = int.tryParse(_units.text);
    if (units == null || units <= 0) return showIosToast(context, 'Informe quantas unidades vão por caixa.', error: true);
    setState(() => _saving = true);
    try {
      await ref.read(logisticsApiProvider).saveBoxStandard(widget.product.id, {
        'units_per_box': units,
        'box_type': _type.text.trim().isEmpty ? null : _type.text.trim(),
        'length_cm': _d(_l),
        'width_cm': _d(_w),
        'height_cm': _d(_h),
        'weight_kg': _d(_kg),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      ref.invalidate(boxStandardsProvider);
      if (mounted) {
        Navigator.pop(context);
        showIosToast(context, 'Padrão salvo: $units un por caixa');
      }
    } catch (e) {
      if (mounted) showIosToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showIosConfirm(context,
        title: 'Remover padrão?', message: 'O modelo deixa de poder ser pedido.', confirmLabel: 'Remover', destructive: true);
    if (!ok) return;
    try {
      await ref.read(logisticsApiProvider).deleteBoxStandard(widget.product.id);
      ref.invalidate(boxStandardsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showIosToast(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = _d(_l) ?? 40, w = _d(_w) ?? 30, h = _d(_h) ?? 30;
    final units = int.tryParse(_units.text);
    final volume = (_d(_l) ?? 0) * (_d(_w) ?? 0) * (_d(_h) ?? 0) / 1e6;
    final num = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.product.name, style: theme.textTheme.headlineMedium),
            Text(widget.product.sku, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 220,
                height: 190,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Box3D(length: l, width: w, height: h, units: units, size: 150),
                    if (volume > 0)
                      Text('${volume.toStringAsFixed(3)} m³', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: !widget.canEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _units,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Unidades por caixa *', suffixText: 'un'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _type, decoration: const InputDecoration(labelText: 'Tipo de caixa', hintText: 'Papelão onda dupla')),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (c, label) in [(_l, 'Comp.'), (_w, 'Larg.'), (_h, 'Alt.')]) ...[
                      Expanded(
                        child: TextField(
                          controller: c,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: num,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: label, suffixText: 'cm'),
                        ),
                      ),
                      if (label != 'Alt.') const SizedBox(width: 8),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _kg,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: num,
                    decoration: const InputDecoration(labelText: 'Peso bruto da caixa cheia', suffixText: 'kg'),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações (empilhamento máx., frágil...)')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (widget.canEdit) ...[
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CupertinoActivityIndicator(color: Colors.white) : const Text('Salvar padrão'),
              ),
              if (widget.existing != null)
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                  child: const Text('Remover padrão'),
                ),
            ] else
              Text('Só o admin altera padrões de caixa.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
