import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String id;
  const ProductDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product  = ref.watch(productDetailProvider(id));
    final user     = ref.watch(currentUserProvider);
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
        data: (p) => ListView(
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
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2, color: AppTheme.primary, size: 26),
                        ),
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
                    Row(
                      children: [
                        Expanded(
                          child: _InfoBox(
                            label: 'Preço de venda',
                            value: currency.format(p.salePrice),
                            valueColor: AppTheme.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoBox(
                            label: 'Custo',
                            value: currency.format(p.costPrice),
                            valueColor: AppTheme.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _InfoBox(
                            label: 'Margem',
                            value: '${p.marginPercent.toStringAsFixed(1)}%',
                            valueColor: p.marginPercent >= 30 ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ],
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(productDetailProvider(id))),
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
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}
