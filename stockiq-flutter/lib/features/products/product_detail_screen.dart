import 'package:flutter/material.dart';
import '../errors/not_found_screen.dart';
import '../../core/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../shared/models/stock_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product  = ref.watch(productDetailProvider(id));
    final user     = ref.watch(currentUserProvider);
    final branchStock = user?.branchId != null
        ? ref.watch(branchStockProvider(user!.branchId!))
        : const AsyncValue<List<StockModel>>.data([]);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produto'),
        actions: [
          if (user?.isManager ?? false)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/products/$id/edit'),
            ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => context.push('/qr/view/$id'),
            tooltip: 'Ver QR Code',
          ),
        ],
      ),
      body: product.when(
        data: (p) => PageContainer(
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Builder(builder: (context) {
                          final size = context.isWide ? 64.0 : 52.0;
                          return Container(
                            width: size, height: size,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.inventory_2, color: AppTheme.primary, size: size * 0.5),
                          );
                        }),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: Theme.of(context).textTheme.titleLarge),
                              Text('SKU: ${p.sku}', style: Theme.of(context).textTheme.bodySmall),
                              if (p.category != null)
                                Text(p.category!, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: p.isActive ? 'Ativo' : 'Inativo',
                          type: p.isActive ? StatusType.success : StatusType.danger,
                        ),
                      ],
                    ),
                    if (p.description != null) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(p.description!, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Preços
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preços', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final boxes = [
                        _InfoBox(
                          label: 'Preço de venda',
                          value: currency.format(p.salePrice),
                          valueColor: AppTheme.success,
                        ),
                        _InfoBox(
                          label: 'Custo',
                          value: currency.format(p.costPrice),
                          valueColor: AppTheme.danger,
                        ),
                        _InfoBox(
                          label: 'Margem',
                          value: '${p.marginPercent.toStringAsFixed(1)}%',
                          valueColor: p.marginPercent >= 30 ? AppTheme.success : AppTheme.warning,
                        ),
                      ];
                      // Em tela larga cada box fica com largura fixa (não
                      // estica full-width) -- em mobile continua Expanded.
                      if (context.isWide) {
                        return Row(
                          children: [
                            for (final (i, box) in boxes.indexed) ...[
                              if (i > 0) const SizedBox(width: 10),
                              SizedBox(width: 200, child: box),
                            ],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          for (final (i, box) in boxes.indexed) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: box),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Saldo atual (filial do usuário)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: branchStock.when(
                  data: (stocks) {
                    StockModel? stock;
                    for (final s in stocks) {
                      if (s.productId == p.id) { stock = s; break; }
                    }
                    final qty = stock?.quantity ?? 0;
                    final isLow = stock?.isLow ?? false;
                    return Row(
                      children: [
                        Icon(Icons.inventory_2, color: isLow ? AppTheme.danger : AppTheme.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saldo atual', style: Theme.of(context).textTheme.bodySmall),
                              Text('$qty ${p.unit}', style: Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                        ),
                        if (isLow) const StatusBadge(label: 'Abaixo do mínimo', type: StatusType.danger),
                      ],
                    );
                  },
                  loading: () => const SizedBox(height: 20, child: LinearProgressIndicator()),
                  error: (_, __) => const Text('Erro ao carregar saldo'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Estoque mínimo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: AppTheme.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estoque mínimo global', style: Theme.of(context).textTheme.bodySmall),
                          Text('${p.minStock} ${p.unit}', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ações
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Registrar entrada'),
                    onPressed: () => context.push('/stock/movement', extra: {
                      'productId': p.id,
                      'type': 'entrada',
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.success,
                      side: const BorderSide(color: AppTheme.success),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Registrar saída'),
                    onPressed: () => context.push('/stock/movement', extra: {
                      'productId': p.id,
                      'type': 'saida',
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is ApiException && e.statusCode == 404
            ? const NotFoundView(title: 'Produto não encontrado', message: 'Esse produto foi removido ou não existe.')
            : ErrorState(message: e.toString(), onRetry: () => ref.invalidate(productDetailProvider(id))),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: context.isWide ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
