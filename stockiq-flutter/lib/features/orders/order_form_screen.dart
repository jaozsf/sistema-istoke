import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/product_model.dart';
import '../../shared/widgets/ios_widgets.dart';
import 'pickers.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

class _Line {
  final ProductModel product;
  final BoxStandard box;
  int boxes = 1;
  bool art = false;
  bool border = false;
  String artNotes = '';
  _Line(this.product, this.box);

  int get units => boxes * box.unitsPerBox;
  bool get isEco => product.name.toLowerCase().contains('ecolog') || product.sku.toUpperCase().startsWith('EC-');
}

/// Vendedor monta o pedido com o cliente: quem compra, qual distribuidora
/// leva, e os modelos EM CAIXAS (o padrão de caixa converte pra unidades).
class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});

  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  Customer? _customer;
  Distributor? _distributor;
  final _lines = <_Line>[];
  final _notes = TextEditingController();
  bool _sending = false;

  int get _boxes => _lines.fold(0, (s, l) => s + l.boxes);
  int get _units => _lines.fold(0, (s, l) => s + l.units);
  double get _weight => _lines.fold(0.0, (s, l) => s + (l.box.weightKg ?? 0) * l.boxes);
  double get _amount => _lines.fold(0.0, (s, l) => s + l.product.salePrice * l.units);

  Future<void> _addProduct() async {
    final picked = await pickProduct(context, ref, exclude: _lines.map((l) => l.product.id).toSet());
    if (picked == null) return;
    setState(() => _lines.add(_Line(picked.$1, picked.$2)));
  }

  Future<void> _send() async {
    if (_customer == null) return showIosToast(context, 'Escolha o cliente.', error: true);
    if (_lines.isEmpty) return showIosToast(context, 'Adicione pelo menos um modelo.', error: true);
    if (_distributor == null) {
      final ok = await showIosConfirm(context,
          title: 'Sem distribuidora?',
          message: 'Dá pra escolher depois, mas a expedição não despacha sem ela.',
          confirmLabel: 'Enviar assim');
      if (!ok) return;
    }
    setState(() => _sending = true);
    try {
      final order = await ref.read(logisticsApiProvider).createOrder(
            customerId: _customer!.id,
            distributorId: _distributor?.id,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            items: [
              for (final l in _lines)
                {
                  'product_id': l.product.id,
                  'quantity_boxes': l.boxes,
                  'has_art': l.art,
                  'has_border': l.border,
                  if (l.artNotes.isNotEmpty) 'art_notes': l.artNotes,
                },
            ],
          );
      invalidateOrders(ref);
      if (!mounted) return;
      showIosToast(context, 'Pedido ${order.code} enviado à fábrica');
      context.pushReplacement('/orders/${order.id}');
    } catch (e) {
      if (mounted) showIosToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(onPressed: () => context.pop(), child: const Text('Cancelar')),
        leadingWidth: 90,
        title: const Text('Novo pedido'),
      ),
      bottomNavigationBar: _Footer(
        boxes: _boxes,
        units: _units,
        weight: _weight,
        amount: _amount,
        sending: _sending,
        onSend: _send,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          IosSection(
            header: '1. Cliente',
            children: [
              IosTile(
                icon: CupertinoIcons.person_crop_circle_fill,
                iconColor: AppTheme.info,
                title: _customer?.name ?? 'Escolher cliente',
                subtitle: _customer?.location.isNotEmpty == true ? _customer!.location : null,
                onTap: () async {
                  final c = await pickCustomer(context, ref);
                  if (c != null) setState(() => _customer = c);
                },
              ),
            ],
          ),
          IosSection(
            header: '2. Distribuidora',
            footer: 'Combinada com o cliente. Dá pra trocar até o despacho.',
            children: [
              IosTile(
                icon: CupertinoIcons.car_detailed,
                iconColor: _distributor == null ? AppTheme.warning : AppTheme.lagoon,
                title: _distributor?.name ?? 'Escolher distribuidora',
                subtitle: _distributor?.regions,
                onTap: () async {
                  final d = await pickDistributor(context, ref, selectedId: _distributor?.id);
                  if (d != null) setState(() => _distributor = d);
                },
              ),
            ],
          ),
          IosSection(
            header: '3. Copos (em caixas fechadas)',
            children: [
              for (final l in _lines) _LineEditor(
                line: l,
                onChanged: () => setState(() {}),
                onRemove: () => setState(() => _lines.remove(l)),
              ),
              IosTile(
                icon: CupertinoIcons.add,
                title: 'Adicionar modelo',
                chevron: false,
                onTap: _addProduct,
              ),
            ],
          ),
          IosSection(
            header: 'Observações',
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _notes,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(hintText: 'Prazo combinado, horário de entrega, contato...'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Ao enviar, o pedido vai pra produção (se tiver arte/borda) ou direto pra expedição.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  final _Line line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _LineEditor({required this.line, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(line.product.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: AppTheme.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(icon: CupertinoIcons.cube_box_fill, color: AppTheme.lagoon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.product.name, style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('${line.boxes} cx × ${line.box.unitsPerBox} = ${line.units} un',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Stepper2(
                  value: line.boxes,
                  min: 1,
                  onChanged: (v) {
                    line.boxes = v;
                    onChanged();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Arte'),
                    avatar: Icon(CupertinoIcons.paintbrush, size: 14, color: line.art ? Colors.white : null),
                    selected: line.art,
                    onSelected: (v) {
                      Haptics.tap();
                      line.art = v;
                      onChanged();
                    },
                  ),
                  FilterChip(
                    label: Text(line.isEco ? 'Borda (não p/ ecológico)' : 'Borda'),
                    avatar: Icon(CupertinoIcons.circle, size: 14, color: line.border ? Colors.white : null),
                    selected: line.border,
                    onSelected: line.isEco
                        ? null
                        : (v) {
                            Haptics.tap();
                            line.border = v;
                            onChanged();
                          },
                  ),
                ],
              ),
            ),
            if (line.art)
              Padding(
                padding: const EdgeInsets.only(left: 42, top: 6),
                child: TextFormField(
                  initialValue: line.artNotes,
                  decoration: const InputDecoration(hintText: 'Descrição da arte (logo, cores, posição)', isDense: true),
                  onChanged: (v) => line.artNotes = v.trim(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int boxes, units;
  final double weight, amount;
  final bool sending;
  final VoidCallback onSend;
  const _Footer({required this.boxes, required this.units, required this.weight, required this.amount, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline, width: .5)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currency.format(amount), style: theme.textTheme.titleLarge),
                  Text(
                    '$boxes cx · $units un${weight > 0 ? ' · ${weight.toStringAsFixed(1)} kg' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator(color: Colors.white))
                  : const Icon(CupertinoIcons.paperplane_fill),
              label: const Text('Enviar à fábrica'),
            ),
          ],
        ),
      ),
    );
  }
}
