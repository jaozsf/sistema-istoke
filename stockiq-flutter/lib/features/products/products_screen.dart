import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/product_model.dart';
import '../../shared/widgets/app_widgets.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user     = ref.watch(currentUserProvider);
    final products = ref.watch(productsProvider(_query));
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          if (user?.isManager ?? false)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/products/new'),
              tooltip: 'Novo produto',
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra de busca
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nome, SKU ou categoria...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = null);
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() => _query = v.length >= 2 ? v : null);
              },
            ),
          ),

          // Lista
          Expanded(
            child: products.when(
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Nenhum produto encontrado',
                    subtitle: _query != null ? 'Tente outra busca.' : 'Cadastre o primeiro produto.',
                    actionLabel: user?.isManager == true ? 'Novo produto' : null,
                    onAction: () => context.push('/products/new'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ProductCard(
                      product: items[i],
                      currency: currency,
                    ),
                  ),
                );
              },
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: List.generate(5, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ShimmerCard(height: 90),
                )),
              ),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(productsProvider(_query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final NumberFormat currency;

  const _ProductCard({required this.product, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/products/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Ícone de categoria
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('SKU: ${product.sku}', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          currency.format(product.salePrice),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: '${product.marginPercent.toStringAsFixed(1)}% margem',
                          type: product.marginPercent >= 30
                              ? StatusType.success
                              : StatusType.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(
                    label: product.isActive ? 'Ativo' : 'Inativo',
                    type: product.isActive ? StatusType.success : StatusType.danger,
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
