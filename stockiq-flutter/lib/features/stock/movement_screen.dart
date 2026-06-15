import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/services/stock_api_service.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.productId == null || widget.branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione produto e filial.'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await StockApiService().registerMovement(
        type:      _type,
        quantity:  int.parse(_qtyCtrl.text),
        productId: widget.productId!,
        branchId:  widget.branchId!,
        notes:     _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );

      ref.invalidate(movementsProvider);
      ref.invalidate(lowStockProvider);
      if (widget.productId != null) ref.invalidate(productDetailProvider(widget.productId!));

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
                  onTap: () => setState(() => _type = 'entrada'),
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
                  onTap: () => setState(() => _type = 'transfer'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Produto selecionado
            if (widget.productId != null) ...[
              _InfoRow(icon: Icons.inventory_2_outlined, label: 'Produto', value: widget.productId!),
              const SizedBox(height: 12),
            ],
            if (widget.branchId != null) ...[
              _InfoRow(icon: Icons.store_outlined, label: 'Filial', value: widget.branchId!),
              const SizedBox(height: 24),
            ],

            // Quantidade
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade *',
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
                      color: color.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(.3)),
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
            color: selected ? color.withOpacity(.12) : Colors.transparent,
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
