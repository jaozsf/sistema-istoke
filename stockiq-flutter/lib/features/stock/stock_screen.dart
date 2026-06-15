import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/movement_model.dart';
import '../../shared/models/stock_model.dart';
import '../../shared/widgets/app_widgets.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Saldo atual'),
            Tab(text: 'Movimentações'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nova movimentação',
            onPressed: () => context.push('/stock/movement'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _StockTab(),
          _MovementsTab(),
        ],
      ),
    );
  }
}

// ── Aba de Saldo ──────────────────────────────────────────────────────────────

class _StockTab extends ConsumerWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(lowStockProvider),
      child: lowStock.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Todos os estoques OK',
              subtitle: 'Nenhum produto abaixo do mínimo.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alerta header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withOpacity(.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length} ${items.length == 1 ? 'item abaixo' : 'itens abaixo'} do mínimo',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.warning),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _StockCard(stock: items[i]),
                ),
              ),
            ],
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerCard(height: 90),
          )),
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(lowStockProvider),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final StockModel stock;
  const _StockCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Produto ${stock.productId.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadge(
                  label: stock.isLow ? 'Crítico' : 'OK',
                  type: stock.isLow ? StatusType.danger : StatusType.success,
                ),
              ],
            ),
            const SizedBox(height: 10),
            StockLevelBar(quantity: stock.quantity, minQuantity: stock.minQuantity),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Entrada'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.success,
                      side: const BorderSide(color: AppTheme.success),
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => context.push('/stock/movement', extra: {
                      'productId': stock.productId,
                      'branchId': stock.branchId,
                      'type': 'entrada',
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.remove, size: 16),
                    label: const Text('Saída'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => context.push('/stock/movement', extra: {
                      'productId': stock.productId,
                      'branchId': stock.branchId,
                      'type': 'saida',
                    }),
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

// ── Aba de Movimentações ──────────────────────────────────────────────────────

class _MovementsTab extends ConsumerWidget {
  const _MovementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(movementsProvider),
      child: movements.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.swap_horiz,
              title: 'Sem movimentações',
              subtitle: 'As movimentações aparecerão aqui.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _MovementCard(movement: items[i]),
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ShimmerCard(height: 70),
          )),
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(movementsProvider),
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final MovementModel movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final (color, icon, sign) = switch (movement.type) {
      'entrada'  => (AppTheme.success, Icons.add_circle,      '+'),
      'saida'    => (AppTheme.danger,  Icons.remove_circle,   '-'),
      'transfer' => (AppTheme.info,    Icons.swap_horiz,      '↔'),
      _          => (AppTheme.warning, Icons.tune,            '~'),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 24),
        title: Row(
          children: [
            Text(
              movement.type.toUpperCase(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                movement.productId,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: movement.notes != null
            ? Text(movement.notes!, style: Theme.of(context).textTheme.bodySmall)
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${movement.quantity}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
            ),
            Text(
              _formatDate(movement.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.day == now.day) return 'Hoje ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
    return '${local.day.toString().padLeft(2,'0')}/${local.month.toString().padLeft(2,'0')} ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
  }
}
