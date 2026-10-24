import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';
import 'pickers.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final _dt = DateFormat("d MMM yyyy, HH:mm", 'pt_BR');

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const OrderDetailScreen({super.key, required this.id});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;
  // Conferência: contagem local enquanto a pessoa toca +/-; vai pro
  // servidor com debounce curto por item (não a cada toque).
  final Map<String, int> _pendingChecks = {};

  Future<void> _run(Future<Order> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      invalidateOrders(ref, widget.id);
      if (mounted && success != null) showIosToast(context, success);
    } catch (e) {
      if (mounted) showIosToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _advance(Order order, OrderStage to) async {
    final api = ref.read(logisticsApiProvider);
    String? note, invoice, tracking;

    if (to == OrderStage.despachado) {
      final r = await _dispatchSheet(order);
      if (r == null) return;
      (invoice, tracking, note) = r;
    } else if (to == OrderStage.conferido) {
      final ok = await showIosConfirm(context,
          title: 'Concluir conferência?',
          message: '${order.totalBoxes} caixa(s) conferidas. O pedido fica pronto pra carregar.',
          confirmLabel: 'Concluir');
      if (!ok) return;
    } else if (to == OrderStage.cancelado) {
      final ok = await showIosConfirm(context,
          title: 'Cancelar ${order.code}?',
          message: order.stockDeducted
              ? 'O estoque já baixado volta pra prateleira e a venda é estornada.'
              : 'O pedido sai da fila de todos os setores.',
          confirmLabel: 'Cancelar pedido',
          destructive: true);
      if (!ok) return;
    } else {
      final ok = await showIosConfirm(context,
          title: '${to.actionLabel}?',
          message: order.stage == OrderStage.enviado
              ? 'O estoque das ${order.totalUnits} unidades é baixado agora.'
              : null);
      if (!ok) return;
    }
    if (!mounted) return;
    await _run(
      () => api.transition(order.id, to, note: note, invoiceNumber: invoice, trackingCode: tracking),
      success: to == OrderStage.cancelado ? 'Pedido cancelado' : 'Pedido em "${to.label}"',
    );
  }

  Future<(String, String, String)?> _dispatchSheet(Order order) {
    final nf = TextEditingController(text: order.invoiceNumber);
    final track = TextEditingController(text: order.trackingCode);
    final note = TextEditingController();
    return showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Despachar ${order.code}', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Entregue para ${order.distributorName}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 18),
            TextField(controller: nf, decoration: const InputDecoration(labelText: 'Nota fiscal (NF)')),
            const SizedBox(height: 10),
            TextField(controller: track, decoration: const InputDecoration(labelText: 'Código de rastreio (opcional)')),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Observação (motorista, placa...)')),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, (nf.text.trim(), track.text.trim(), note.text.trim())),
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Confirmar despacho'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeDistributor(Order order) async {
    final picked = await pickDistributor(context, ref, selectedId: order.distributorId);
    if (picked == null || !mounted) return;
    await _run(
      () => ref.read(logisticsApiProvider).updateOrder(order.id, distributorId: picked.id),
      success: 'Distribuidora: ${picked.name}',
    );
  }

  void _setCheck(Order order, OrderItem item, int value) {
    setState(() => _pendingChecks[item.id] = value);
    Future.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted || _pendingChecks[item.id] != value) return; // veio outro toque depois
      try {
        await ref.read(logisticsApiProvider).checkItem(order.id, item.id, value);
        _pendingChecks.remove(item.id);
        invalidateOrders(ref, order.id);
        if (value == item.quantityBoxes) Haptics.success();
      } catch (e) {
        if (mounted) {
          setState(() => _pendingChecks.remove(item.id));
          showIosToast(context, e.toString(), error: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderDetailProvider(widget.id));
    final user = ref.watch(currentUserProvider);

    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CupertinoActivityIndicator(radius: 14))),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(orderDetailProvider(widget.id))),
      ),
      data: (order) {
        final canCheck = order.stage == OrderStage.emSeparacao &&
            ((user?.isShipping ?? false) || (user?.isManager ?? false));
        final canEditDistributor = order.isOpen && (user?.canSell ?? false);
        final primary = order.primaryAction;

        return Scaffold(
          bottomNavigationBar: (primary != null || order.canCancel || order.canReopenCheck)
              ? _ActionBar(
                  busy: _busy,
                  primary: primary,
                  blockedReason: primary == OrderStage.conferido && order.checkedBoxes < order.totalBoxes
                      ? 'Faltam ${order.totalBoxes - order.checkedBoxes} caixa(s) pra conferir'
                      : primary == OrderStage.despachado && order.distributorId == null
                          ? 'Escolha a distribuidora antes'
                          : null,
                  onPrimary: primary == null ? null : () => _advance(order, primary),
                  onCancel: order.canCancel ? () => _advance(order, OrderStage.cancelado) : null,
                  onReopen: order.canReopenCheck ? () => _advance(order, OrderStage.emSeparacao) : null,
                )
              : null,
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: Text('Pedido ${order.code}'),
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                surfaceTintColor: Colors.transparent,
              ),
              CupertinoSliverRefreshControl(onRefresh: () async => invalidateOrders(ref, order.id)),
              SliverCenter(sliver: SliverToBoxAdapter(child: _Header(order: order))),
              SliverCenter(sliver: SliverToBoxAdapter(child: _Timeline(order: order))),
              SliverCenter(
                sliver: SliverToBoxAdapter(
                  child: IosSection(
                    header: canCheck ? 'Conferência de caixas' : 'Itens',
                    footer: canCheck ? 'Conte as caixas fechadas de cada modelo e ajuste o número.' : null,
                    children: [
                      for (final item in order.items)
                        _ItemRow(
                          item: item,
                          checking: canCheck,
                          checkedValue: _pendingChecks[item.id] ?? item.checkedBoxes,
                          onCheck: (v) => _setCheck(order, item, v),
                          showCheckState: order.stage.index >= OrderStage.emSeparacao.index &&
                              order.stage != OrderStage.cancelado,
                        ),
                    ],
                  ),
                ),
              ),
              SliverCenter(
                sliver: SliverToBoxAdapter(
                  child: IosSection(
                    header: 'Logística',
                    children: [
                      IosTile(
                        icon: CupertinoIcons.car_detailed,
                        iconColor: order.distributorName == null ? AppTheme.warning : AppTheme.lagoon,
                        title: order.distributorName ?? 'Escolher distribuidora',
                        subtitle: 'Definida pelo vendedor com o cliente',
                        onTap: canEditDistributor ? () => _changeDistributor(order) : null,
                      ),
                      IosTile(
                        icon: CupertinoIcons.cube_box_fill,
                        iconColor: AppTheme.deep,
                        title: 'Volumes',
                        value: '${order.totalBoxes} cx',
                        chevron: false,
                      ),
                      IosTile(
                        icon: CupertinoIcons.gauge,
                        iconColor: AppTheme.info,
                        title: 'Peso bruto estimado',
                        value: order.totalWeightKg > 0 ? '${order.totalWeightKg.toStringAsFixed(1)} kg' : '—',
                        chevron: false,
                      ),
                      if (order.invoiceNumber != null)
                        IosTile(icon: CupertinoIcons.doc_text, iconColor: AppTheme.success, title: 'Nota fiscal', value: order.invoiceNumber, chevron: false),
                      if (order.trackingCode != null)
                        IosTile(icon: CupertinoIcons.barcode, iconColor: AppTheme.success, title: 'Rastreio', value: order.trackingCode, chevron: false),
                    ],
                  ),
                ),
              ),
              SliverCenter(
                sliver: SliverToBoxAdapter(
                  child: IosSection(
                    header: 'Comercial',
                    children: [
                      IosTile(icon: CupertinoIcons.person_fill, iconColor: AppTheme.info, title: 'Vendedor', value: order.sellerName ?? '—', chevron: false),
                      IosTile(icon: CupertinoIcons.money_dollar_circle_fill, iconColor: AppTheme.success, title: 'Valor dos copos', value: _currency.format(order.totalAmount), chevron: false),
                      if (order.notes != null && order.notes!.isNotEmpty)
                        IosTile(icon: CupertinoIcons.text_bubble_fill, iconColor: AppTheme.warning, title: order.notes!, chevron: false),
                      if (order.checkNotes != null && order.checkNotes!.isNotEmpty)
                        IosTile(icon: CupertinoIcons.exclamationmark_bubble_fill, iconColor: AppTheme.danger, title: 'Divergência', subtitle: order.checkNotes, chevron: false),
                    ],
                  ),
                ),
              ),
              SliverCenter(sliver: SliverToBoxAdapter(child: _History(order: order))),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        );
      },
    );
  }
}

// ── Cabeçalho ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Order order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(order.stage.icon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(order.stage.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dt.format(order.createdAt),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(order.customerName ?? 'Cliente',
              style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
          if (order.customerCity != null)
            Text(order.customerCity!, style: TextStyle(color: Colors.white.withValues(alpha: .85))),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderStat(label: 'Caixas', value: '${order.totalBoxes}'),
              _HeaderStat(label: 'Unidades', value: NumberFormat.decimalPattern('pt_BR').format(order.totalUnits)),
              _HeaderStat(label: 'Conferidas', value: '${order.checkedBoxes}/${order.totalBoxes}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12)),
          ],
        ),
      );
}

// ── Linha do tempo das etapas ─────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final Order order;
  const _Timeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = [
      for (final s in OrderStage.flow)
        if (s != OrderStage.emProducao || order.needsProduction) s,
    ];
    final cancelled = order.stage == OrderStage.cancelado;
    // Etapa mais longe alcançada (pra pedido cancelado, olha o histórico)
    final reached = cancelled
        ? order.events.map((e) => OrderStage.of(e.toStatus)).where((s) => s != OrderStage.cancelado).fold<int>(0, (m, s) => s.index > m ? s.index : m)
        : order.stage.index;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stages[i].index <= reached
                            ? (cancelled ? AppTheme.danger.withValues(alpha: .7) : stages[i].color)
                            : theme.colorScheme.surfaceContainerHighest,
                        boxShadow: stages[i].index == reached && !cancelled
                            ? [BoxShadow(color: stages[i].color.withValues(alpha: .4), blurRadius: 12)]
                            : null,
                      ),
                      child: Icon(
                        stages[i].index < reached ? CupertinoIcons.checkmark_alt : stages[i].icon,
                        size: 17,
                        color: stages[i].index <= reached ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stages[i].label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: stages[i].index == reached ? FontWeight.w700 : FontWeight.w400,
                        color: stages[i].index == reached ? theme.colorScheme.onSurface : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Item ──────────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final OrderItem item;
  final bool checking;
  final bool showCheckState;
  final int checkedValue;
  final ValueChanged<int> onCheck;
  const _ItemRow({
    required this.item,
    required this.checking,
    required this.checkedValue,
    required this.onCheck,
    required this.showCheckState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = checkedValue >= item.quantityBoxes;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: IconBadge(
              key: ValueKey(done && showCheckState),
              icon: done && showCheckState ? CupertinoIcons.checkmark_alt : CupertinoIcons.cube_box_fill,
              color: done && showCheckState ? AppTheme.success : AppTheme.lagoon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${item.quantityBoxes} cx × ${item.unitsPerBox} = ${item.quantityUnits} un · ${item.productSku}',
                  style: theme.textTheme.bodySmall,
                ),
                if (item.customization.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, children: [
                    if (item.hasArt) _Tag(label: 'Arte', color: const Color(0xFF8E6BD8)),
                    if (item.hasBorder) _Tag(label: 'Borda', color: AppTheme.warning),
                  ]),
                ],
                if (item.artNotes != null && item.artNotes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Arte: ${item.artNotes}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          if (checking)
            Stepper2(value: checkedValue, max: item.quantityBoxes, onChanged: onCheck)
          else if (showCheckState)
            Text('${item.checkedBoxes}/${item.quantityBoxes}',
                style: TextStyle(fontWeight: FontWeight.w600, color: done ? AppTheme.success : AppTheme.warning)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

// ── Histórico ─────────────────────────────────────────────────────────────────

class _History extends StatelessWidget {
  final Order order;
  const _History({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = order.events.reversed.toList();
    return IosSection(
      header: 'Histórico',
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(OrderStage.of(e.toStatus).icon, size: 18, color: OrderStage.of(e.toStatus).color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(OrderStage.of(e.toStatus).label, style: theme.textTheme.titleMedium),
                      Text('${e.userName ?? 'Sistema'} · ${_dt.format(e.createdAt)}', style: theme.textTheme.bodySmall),
                      if (e.note != null && e.note!.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.note!, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Barra de ação fixa ────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool busy;
  final OrderStage? primary;
  final String? blockedReason;
  final VoidCallback? onPrimary, onCancel, onReopen;
  const _ActionBar({required this.busy, this.primary, this.blockedReason, this.onPrimary, this.onCancel, this.onReopen});

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (blockedReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(blockedReason!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.warning)),
              ),
            Row(
              children: [
                if (onCancel != null || onReopen != null)
                  PopupMenuButton<String>(
                    icon: const Icon(CupertinoIcons.ellipsis_circle),
                    onSelected: (v) => v == 'cancel' ? onCancel?.call() : onReopen?.call(),
                    itemBuilder: (_) => [
                      if (onReopen != null) const PopupMenuItem(value: 'reopen', child: Text('Reabrir conferência')),
                      if (onCancel != null)
                        const PopupMenuItem(value: 'cancel', child: Text('Cancelar pedido', style: TextStyle(color: AppTheme.danger))),
                    ],
                  ),
                if (primary != null)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || blockedReason != null ? null : onPrimary,
                      icon: busy
                          ? const SizedBox(width: 18, height: 18, child: CupertinoActivityIndicator(color: Colors.white))
                          : Icon(primary!.icon),
                      label: Text(primary!.actionLabel),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
