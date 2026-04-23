import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final lowStock  = ref.watch(lowStockProvider);
    final movements = ref.watch(movementsProvider);
    final currency  = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olá, ${user?.fullName.split(' ').first ?? 'Usuário'} 👋',
                style: const TextStyle(fontSize: 15)),
            Text(
              DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lowStockProvider);
          ref.invalidate(movementsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Métricas
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                MetricCard(
                  label: 'Receita hoje',
                  value: currency.format(18420),
                  delta: '+12% vs ontem',
                  deltaPositive: true,
                ),
                MetricCard(
                  label: 'Lucro líquido',
                  value: currency.format(8580),
                  delta: '+19% vs ontem',
                  deltaPositive: true,
                  valueColor: AppTheme.success,
                ),
                MetricCard(
                  label: 'Movimentações',
                  value: '48',
                  delta: 'Hoje',
                  deltaPositive: true,
                ),
                lowStock.when(
                  data: (items) => MetricCard(
                    label: 'Alertas de estoque',
                    value: '${items.length}',
                    delta: items.isEmpty ? 'Tudo OK' : 'Itens críticos',
                    deltaPositive: items.isEmpty,
                    valueColor: items.isNotEmpty ? AppTheme.warning : null,
                  ),
                  loading: () => const ShimmerCard(height: 80),
                  error: (_, __) => const MetricCard(label: 'Alertas', value: '--'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Alertas de estoque baixo
            lowStock.when(
              data: (items) {
                if (items.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Alertas de estoque',
                      action: 'Ver todos',
                      onAction: () => context.go('/stock'),
                    ),
                    const SizedBox(height: 8),
                    ...items.take(3).map((s) => _AlertTile(stock: s)),
                    const SizedBox(height: 20),
                  ],
                );
              },
              loading: () => const ShimmerCard(height: 120),
              error: (_, __) => const SizedBox(),
            ),

            // Movimentações recentes
            SectionHeader(
              title: 'Movimentações recentes',
              action: 'Ver todas',
              onAction: () => context.go('/stock'),
            ),
            const SizedBox(height: 8),
            movements.when(
              data: (items) => Column(
                children: items.take(5).map((m) => _MovementTile(movement: m)).toList(),
              ),
              loading: () => Column(
                children: List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerCard(height: 62),
                )),
              ),
              error: (e, _) => ErrorState(
                message: 'Erro ao carregar movimentações',
                onRetry: () => ref.invalidate(movementsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final dynamic stock;
  const _AlertTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
        ),
        title: Text('Estoque abaixo do mínimo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${stock.quantity} unid disponíveis (mín ${stock.minQuantity})',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.go('/stock'),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final dynamic movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isEntrada = movement.type == 'entrada';
    final color = isEntrada ? AppTheme.success : AppTheme.danger;
    final icon  = isEntrada ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final sign  = isEntrada ? '+' : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          movement.type.toString().toUpperCase(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(movement.productId, style: Theme.of(context).textTheme.bodySmall),
        trailing: Text(
          '$sign${movement.quantity}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}
