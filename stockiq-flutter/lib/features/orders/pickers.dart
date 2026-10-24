import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/product_model.dart';
import '../../shared/widgets/ios_widgets.dart';
import '../admin/customers_screen.dart' show showCustomerEditor;

/// Sheets de seleção usados no pedido. Tudo em bottom sheet arrastável
/// (padrão iOS de "picker" modal), com busca no topo.

Future<T?> _sheet<T>(BuildContext context, Widget Function(ScrollController) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (_, controller) => builder(controller),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  const _SearchField({required this.onChanged, required this.hint});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: CupertinoSearchTextField(
          placeholder: hint,
          onChanged: onChanged,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
}

// ── Distribuidora ─────────────────────────────────────────────────────────────

Future<Distributor?> pickDistributor(BuildContext context, WidgetRef ref, {String? selectedId}) {
  return _sheet<Distributor>(context, (controller) => Consumer(builder: (context, ref, _) {
        final list = ref.watch(distributorsProvider(false));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Distribuidora', style: Theme.of(context).textTheme.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Combine com o cliente quem leva a carga.', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: list.when(
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (items) => items.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Nenhuma distribuidora cadastrada. Peça ao admin cadastrar em Gestão.', textAlign: TextAlign.center),
                      ))
                    : ListView(
                        controller: controller,
                        children: [
                          IosSection(children: [
                            for (final d in items)
                              IosTile(
                                icon: CupertinoIcons.car_detailed,
                                title: d.name,
                                subtitle: [d.regions, d.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                                trailing: d.id == selectedId
                                    ? Icon(CupertinoIcons.checkmark_alt, color: AppTheme.accentOf(context))
                                    : null,
                                chevron: false,
                                onTap: () => Navigator.pop(context, d),
                              ),
                          ]),
                        ],
                      ),
              ),
            ),
          ],
        );
      }));
}

// ── Cliente ───────────────────────────────────────────────────────────────────

Future<Customer?> pickCustomer(BuildContext context, WidgetRef ref) {
  return _sheet<Customer>(context, (controller) => _CustomerPicker(controller: controller));
}

class _CustomerPicker extends ConsumerStatefulWidget {
  final ScrollController controller;
  const _CustomerPicker({required this.controller});

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(customersProvider(_q));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
          child: Row(
            children: [
              Expanded(child: Text('Cliente', style: Theme.of(context).textTheme.headlineMedium)),
              TextButton.icon(
                onPressed: () async {
                  final created = await showCustomerEditor(context, ref);
                  if (created != null && context.mounted) Navigator.pop(context, created);
                },
                icon: const Icon(CupertinoIcons.person_add),
                label: const Text('Novo'),
              ),
            ],
          ),
        ),
        _SearchField(hint: 'Nome, cidade ou CNPJ', onChanged: (v) => setState(() => _q = v.trim())),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (items) => items.isEmpty
                ? const Center(child: Text('Nenhum cliente. Toque em "Novo".'))
                : ListView(
                    controller: widget.controller,
                    children: [
                      IosSection(children: [
                        for (final c in items)
                          IosTile(
                            icon: CupertinoIcons.person_crop_circle_fill,
                            iconColor: AppTheme.info,
                            title: c.name,
                            subtitle: [c.location, c.document].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                            chevron: false,
                            onTap: () => Navigator.pop(context, c),
                          ),
                      ]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Produto (só os que têm padrão de caixa) ───────────────────────────────────

Future<(ProductModel, BoxStandard)?> pickProduct(BuildContext context, WidgetRef ref, {Set<String> exclude = const {}}) {
  return _sheet<(ProductModel, BoxStandard)>(context, (controller) => _ProductPicker(controller: controller, exclude: exclude));
}

class _ProductPicker extends ConsumerStatefulWidget {
  final ScrollController controller;
  final Set<String> exclude;
  const _ProductPicker({required this.controller, required this.exclude});

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(null));
    final boxes = ref.watch(boxStandardsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('Modelo de copo', style: Theme.of(context).textTheme.headlineMedium)),
        ),
        _SearchField(hint: 'Buscar modelo', onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (all) {
              final boxMap = boxes.valueOrNull ?? {};
              final filtered = all
                  .where((p) => p.isActive && !widget.exclude.contains(p.id))
                  .where((p) => _q.isEmpty || p.name.toLowerCase().contains(_q) || p.sku.toLowerCase().contains(_q))
                  .toList()
                ..sort((a, b) => (boxMap.containsKey(a.id) ? 0 : 1).compareTo(boxMap.containsKey(b.id) ? 0 : 1));
              return ListView(
                controller: widget.controller,
                children: [
                  IosSection(
                    footer: 'Modelos sem padrão de caixa não podem ser pedidos — o admin cadastra em Gestão > Padrões de caixa.',
                    children: [
                      for (final p in filtered)
                        Builder(builder: (context) {
                          final box = boxMap[p.id];
                          return Opacity(
                            opacity: box == null ? .45 : 1,
                            child: IosTile(
                              icon: CupertinoIcons.cube_box_fill,
                              iconColor: box == null ? Colors.grey : AppTheme.lagoon,
                              title: p.name,
                              subtitle: box == null ? 'Sem padrão de caixa' : 'Caixa com ${box.unitsPerBox} un · ${p.sku}',
                              chevron: false,
                              onTap: box == null ? null : () => Navigator.pop(context, (p, box)),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
