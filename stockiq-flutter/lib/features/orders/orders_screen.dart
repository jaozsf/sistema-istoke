import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/animations.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';

/// Filtro inicial conforme o setor: cada um abre direto na fila dele.
String _defaultFilter(UserModel? u) {
  if (u == null) return 'abertos';
  if (u.isProduction) return 'enviado,em_producao';
  if (u.isShipping) return 'enviado,em_separacao,conferido';
  return 'abertos';
}

final _orderFilterProvider = StateProvider<String?>((ref) => _defaultFilter(ref.read(currentUserProvider)));

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final filter = ref.watch(_orderFilterProvider);
    final orders = ref.watch(ordersProvider(filter));
    final summary = ref.watch(orderSummaryProvider);

    final title = switch (user) {
      final u? when u.isProduction => 'Fila da produção',
      final u? when u.isShipping => 'Expedição',
      final u? when u.isSeller => 'Meus pedidos',
      _ => 'Pedidos',
    };

    final filters = <(String?, String)>[
      if (user?.isProduction ?? false) ('enviado,em_producao', 'Minha fila'),
      if (user?.isShipping ?? false) ('enviado,em_separacao,conferido', 'Minha fila'),
      ('abertos', 'Em andamento'),
      for (final s in OrderStage.values) (s.value, s.label),
      (null, 'Todos'),
    ];

    return IosPage(
      title: title,
      onRefresh: () async => invalidateOrders(ref),
      floatingActionButton: (user?.canSell ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/orders/new'),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('Novo pedido', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: summary.maybeWhen(
            data: (s) => _Pipeline(summary: s, onTap: (st) => ref.read(_orderFilterProvider.notifier).state = st.value),
            orElse: () => const SizedBox(height: 92),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (value, label) = filters[i];
                final selected = value == filter;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    Haptics.tap();
                    ref.read(_orderFilterProvider.notifier).state = value;
                  },
                );
              },
            ),
          ),
        ),
        orders.when(
          data: (list) => list.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: CupertinoIcons.cube_box,
                    title: 'Nenhum pedido aqui',
                    subtitle: (user?.canSell ?? false)
                        ? 'Toque em "Novo pedido" pra enviar o primeiro à fábrica.'
                        : 'Quando chegar pedido pro seu setor ele aparece aqui.',
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => OrderCard(order: list[i]).entrance(index: i),
                  ),
                ),
          loading: () => SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, __) => const ShimmerCard(height: 118),
            ),
          ),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(message: e.toString(), onRetry: () => invalidateOrders(ref)),
          ),
        ),
      ],
    );
  }
}

/// Faixa com as etapas e quantos pedidos tem em cada uma -- visão de
/// "esteira" da fábrica, toque filtra a lista.
class _Pipeline extends StatelessWidget {
  final OrderSummary summary;
  final ValueChanged<OrderStage> onTap;
  const _Pipeline({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: OrderStage.flow.length,
        separatorBuilder: (_, __) => Icon(CupertinoIcons.chevron_right, size: 14, color: theme.colorScheme.outline),
        itemBuilder: (_, i) {
          final st = OrderStage.flow[i];
          final n = summary.of(st);
          return GestureDetector(
            onTap: () {
              Haptics.tap();
              onTap(st);
            },
            child: Container(
              width: 96,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: n > 0 ? Border.all(color: st.color.withValues(alpha: .45)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(st.icon, size: 16, color: st.color),
                      const Spacer(),
                      Text('$n', style: theme.textTheme.titleLarge?.copyWith(color: n > 0 ? st.color : null)),
                    ],
                  ),
                  Text(st.label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final when = DateFormat("d MMM, HH:mm", 'pt_BR').format(order.createdAt);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Haptics.tap();
          context.push('/orders/${order.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(order.code, style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.accentOf(context))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(when, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  StagePill(stage: order.stage, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(order.customerName ?? 'Cliente', style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Meta(icon: CupertinoIcons.cube_box, text: '${order.totalBoxes} cx · ${order.totalUnits} un'),
                  if (order.customerCity != null) _Meta(icon: CupertinoIcons.location, text: order.customerCity!),
                  _Meta(
                    icon: CupertinoIcons.car_detailed,
                    text: order.distributorName ?? 'Sem distribuidora',
                    color: order.distributorName == null ? AppTheme.warning : null,
                  ),
                  if (order.needsProduction) const _Meta(icon: CupertinoIcons.paintbrush, text: 'Personalizado'),
                ],
              ),
              if (order.stage == OrderStage.emSeparacao) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: order.checkProgress,
                          minHeight: 6,
                          color: order.checkProgress >= 1 ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${order.checkedBoxes}/${order.totalBoxes} cx',
                        style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Meta({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: TextStyle(fontSize: 13, color: c), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
