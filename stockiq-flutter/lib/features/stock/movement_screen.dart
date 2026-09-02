import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/services/stock_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/product_model.dart';

class MovementScreen extends ConsumerStatefulWidget {
  final String? productId;
  final String? branchId;
  final String initialType;

  const MovementScreen({
    super.key,
    this.productId,
    this.branchId,
    this.initialType = 'entrada',
  });

  @override
  ConsumerState<MovementScreen> createState() => _MovementScreenState();
}

class _MovementScreenState extends ConsumerState<MovementScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _qtyCtrl    = TextEditingController();
  final _notesCtrl  = TextEditingController();
  late String _type;
  bool _loading     = false;
  String? _selectedProductId;
  bool _hasArt    = false;
  bool _hasBorder = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedProductId = widget.productId;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final branchId = widget.branchId ?? ref.read(currentUserProvider)?.branchId;
    final productId = _selectedProductId;
    if (productId == null || branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(productId == null ? 'Selecione um produto.' : 'Filial não encontrada.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await StockApiService().registerMovement(
        type:      _type,
        quantity:  int.parse(_qtyCtrl.text),
        productId: productId,
        branchId:  branchId,
        notes:     _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        hasArt:    _type == 'saida' && _hasArt,
        hasBorder: _type == 'saida' && _hasBorder,
      );

      ref.invalidate(movementsProvider);
      ref.invalidate(lowStockProvider);
      ref.invalidate(branchStockProvider(branchId));
      ref.invalidate(productDetailProvider(productId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Movimentação registrada: $_type de ${_qtyCtrl.text} unid.'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar movimentação')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tipo de movimentação
            Text('Tipo', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(
                  label: 'Entrada',
                  icon: Icons.add_circle_outline,
                  color: AppTheme.success,
                  selected: _type == 'entrada',
                  onTap: () => setState(() { _type = 'entrada'; _hasArt = false; _hasBorder = false; }),
                ),
                const SizedBox(width: 10),
                _TypeChip(
                  label: 'Saída',
                  icon: Icons.remove_circle_outline,
                  color: AppTheme.danger,
                  selected: _type == 'saida',
                  onTap: () => setState(() => _type = 'saida'),
                ),
                const SizedBox(width: 10),
                _TypeChip(
                  label: 'Transfer',
                  icon: Icons.swap_horiz,
                  color: AppTheme.info,
                  selected: _type == 'transfer',
                  onTap: () => setState(() { _type = 'transfer'; _hasArt = false; _hasBorder = false; }),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Produto
            if (widget.productId != null)
              Consumer(
                builder: (context, ref, _) {
                  final product = ref.watch(productDetailProvider(widget.productId!));
                  return _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'Produto',
                    value: product.when(
                      data: (p) => p.name,
                      loading: () => 'Carregando...',
                      error: (_, __) => widget.productId!,
                    ),
                  );
                },
              )
            else
              Consumer(
                builder: (context, ref, _) {
                  final products = ref.watch(productsProvider(null));
                  return products.when(
                    data: (items) => DropdownButtonFormField<String>(
                      initialValue: _selectedProductId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Produto *',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                      ),
                      items: items
                          .map((ProductModel p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (${p.sku})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedProductId = v),
                      validator: (v) => v == null ? 'Selecione um produto.' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Erro ao carregar produtos.'),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Personalização (só faz sentido depois de tirar do estoque)
            if (_type == 'saida' && _selectedProductId != null)
              Consumer(
                builder: (context, ref, _) {
                  final product = ref.watch(productDetailProvider(_selectedProductId!));
                  return product.when(
                    data: (p) {
                      final isEcologico = p.sku.toUpperCase().startsWith('EC-') ||
                          p.name.toLowerCase().contains('ecolog');
                      if (_hasBorder && isEcologico) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => setState(() => _hasBorder = false),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Personalização (pode marcar as duas)', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('Personalizado / arte (+R\$2,00)'),
                                  selected: _hasArt,
                                  onSelected: (v) => setState(() => _hasArt = v),
                                ),
                                FilterChip(
                                  label: const Text('Com borda (+R\$1,00)'),
                                  selected: _hasBorder,
                                  onSelected: isEcologico
                                      ? null
                                      : (v) => setState(() => _hasBorder = v),
                                ),
                              ],
                            ),
                            if (_hasArt && _hasBorder) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Ordem de produção: arte primeiro, depois borda.',
                                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.info),
                              ),
                            ],
                            if (isEcologico) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Copo ecológico não pode ter borda — derrete no processo.',
                                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.warning),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  );
                },
              ),

            // Atalho de caixa fechada (50 und)
            Text('Caixa fechada (50 und)', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 3, 5, 10].map((n) {
                return ActionChip(
                  label: Text('$n cx (${n * 50})'),
                  onPressed: () => setState(() => _qtyCtrl.text = (n * 50).toString()),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Quantidade
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade *',
                hintText: 'Ou digite a quantidade exata (caixa aberta)',
                prefixIcon: Icon(Icons.numbers, size: 20),
              ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe a quantidade.';
                if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Quantidade inválida.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Observações
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                prefixIcon: Icon(Icons.notes, size: 20),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            // Resumo visual
            if (_qtyCtrl.text.isNotEmpty)
              ValueListenableBuilder(
                valueListenable: _qtyCtrl,
                builder: (_, __, ___) {
                  final qty = int.tryParse(_qtyCtrl.text) ?? 0;
                  if (qty <= 0) return const SizedBox();
                  final color = _type == 'entrada' ? AppTheme.success : _type == 'saida' ? AppTheme.danger : AppTheme.info;
                  final sign  = _type == 'entrada' ? '+' : _type == 'saida' ? '-' : '↔';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: .3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$sign$qty unid',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _type.toUpperCase(),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
                        ),
                      ],
                    ),
                  );
                },
              ),

            ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: _type == 'entrada'
                    ? AppTheme.success
                    : _type == 'saida'
                        ? AppTheme.danger
                        : AppTheme.info,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Confirmar $_type'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Theme.of(context).colorScheme.outline,
              width: selected ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Theme.of(context).colorScheme.outline, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
