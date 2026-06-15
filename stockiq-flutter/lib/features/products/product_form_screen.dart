import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/services/stock_api_service.dart';
import '../../core/theme/app_theme.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _skuCtrl     = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _catCtrl     = TextEditingController();
  final _saleCtrl    = TextEditingController();
  final _costCtrl    = TextEditingController();
  final _minCtrl     = TextEditingController(text: '0');
  String _unit       = 'unid';
  bool _loading      = false;
  bool _initialized  = false;

  bool get isEditing => widget.productId != null;

  @override
  void dispose() {
    for (final c in [_skuCtrl, _nameCtrl, _descCtrl, _catCtrl, _saleCtrl, _costCtrl, _minCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(product) {
    if (_initialized) return;
    _initialized = true;
    _skuCtrl.text  = product.sku;
    _nameCtrl.text = product.name;
    _descCtrl.text = product.description ?? '';
    _catCtrl.text  = product.category ?? '';
    _saleCtrl.text = product.salePrice.toString();
    _costCtrl.text = product.costPrice.toString();
    _minCtrl.text  = product.minStock.toString();
    _unit          = product.unit;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final data = {
      'sku':        _skuCtrl.text.trim(),
      'name':       _nameCtrl.text.trim(),
      'description':_descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'category':   _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim(),
      'unit':       _unit,
      'sale_price': double.parse(_saleCtrl.text.replaceAll(',', '.')),
      'cost_price': double.parse(_costCtrl.text.replaceAll(',', '.')),
      'min_stock':  int.parse(_minCtrl.text),
    };

    try {
      final api = StockApiService();
      if (isEditing) {
        await api.updateProduct(widget.productId!, data);
        ref.invalidate(productDetailProvider(widget.productId!));
      } else {
        await api.createProduct(data);
      }
      ref.invalidate(productsProvider(null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Produto atualizado!' : 'Produto criado!'),
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
    // Se editando, carrega dados atuais
    if (isEditing) {
      final product = ref.watch(productDetailProvider(widget.productId!));
      product.whenData(_prefill);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar produto' : 'Novo produto'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Identificação'),
            _field(_skuCtrl, 'SKU *', hint: 'Ex: A-001', enabled: !isEditing,
              validator: (v) => v!.isEmpty ? 'Informe o SKU.' : null),
            _field(_nameCtrl, 'Nome do produto *',
              validator: (v) => v!.isEmpty ? 'Informe o nome.' : null),
            _field(_catCtrl, 'Categoria', hint: 'Ex: Computadores'),
            _field(_descCtrl, 'Descrição', maxLines: 3),

            const SizedBox(height: 8),
            _section('Unidade'),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(labelText: 'Unidade'),
              items: ['unid', 'kg', 'g', 'L', 'mL', 'cx', 'par', 'm']
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unit = v!),
            ),
            const SizedBox(height: 16),

            _section('Preços'),
            Row(children: [
              Expanded(child: _field(_saleCtrl, 'Preço de venda (R\$) *',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                validator: (v) => v!.isEmpty ? 'Informe o preço.' : null)),
              const SizedBox(width: 12),
              Expanded(child: _field(_costCtrl, 'Custo (R\$) *',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                validator: (v) => v!.isEmpty ? 'Informe o custo.' : null)),
            ]),

            // Preview de margem
            ValueListenableBuilder(
              valueListenable: _saleCtrl,
              builder: (_, __, ___) => ValueListenableBuilder(
                valueListenable: _costCtrl,
                builder: (_, __, ___) {
                  final sale = double.tryParse(_saleCtrl.text.replaceAll(',', '.')) ?? 0;
                  final cost = double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? 0;
                  final margin = sale > 0 ? ((sale - cost) / sale * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Margem: ${margin.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: margin >= 30 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                  );
                },
              ),
            ),

            _section('Estoque'),
            _field(_minCtrl, 'Estoque mínimo',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
  );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
}
