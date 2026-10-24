import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';

/// Formulário de cliente em sheet -- usado aqui e no "Novo" do pedido.
Future<Customer?> showCustomerEditor(BuildContext context, WidgetRef ref, {Customer? existing}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CustomerEditor(existing: existing),
  );
}

class _CustomerEditor extends ConsumerStatefulWidget {
  final Customer? existing;
  const _CustomerEditor({this.existing});

  @override
  ConsumerState<_CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends ConsumerState<_CustomerEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _doc = TextEditingController(text: widget.existing?.document);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _city = TextEditingController(text: widget.existing?.city);
  late final _state = TextEditingController(text: widget.existing?.state);
  late final _address = TextEditingController(text: widget.existing?.address);
  bool _saving = false;

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showIosToast(context, 'Informe o nome.', error: true);
    setState(() => _saving = true);
    try {
      final saved = await ref.read(logisticsApiProvider).saveCustomer(widget.existing?.id, {
        'name': _name.text.trim(),
        'document': _v(_doc),
        'phone': _v(_phone),
        'email': _v(_email),
        'city': _v(_city),
        'state': _v(_state)?.toUpperCase(),
        'address': _v(_address),
      });
      ref.invalidate(customersProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showIosToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Novo cliente' : 'Editar cliente', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            TextField(controller: _name, autofocus: widget.existing == null, decoration: const InputDecoration(labelText: 'Nome / razão social *')),
            const SizedBox(height: 10),
            TextField(controller: _doc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CPF / CNPJ')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(flex: 3, child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'Cidade'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _state, maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'UF', counterText: ''))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço de entrega')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const CupertinoActivityIndicator(color: Colors.white) : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(customersProvider(_q));
    return IosPage(
      title: 'Clientes',
      onRefresh: () async => ref.invalidate(customersProvider),
      actions: [
        IconButton(
          icon: const Icon(CupertinoIcons.person_add),
          onPressed: () => showCustomerEditor(context, ref),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CupertinoSearchTextField(
              placeholder: 'Nome, cidade ou CNPJ',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
        ),
        list.when(
          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator())),
          error: (e, _) => SliverToBoxAdapter(child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(customersProvider))),
          data: (items) => SliverToBoxAdapter(
            child: items.isEmpty
                ? EmptyState(
                    icon: CupertinoIcons.person_2,
                    title: 'Nenhum cliente',
                    subtitle: 'Cadastre quem compra os copos pra montar pedidos.',
                    actionLabel: 'Novo cliente',
                    onAction: () => showCustomerEditor(context, ref),
                  )
                : IosSection(
                    header: '${items.length} cliente(s)',
                    children: [
                      for (final c in items)
                        IosTile(
                          icon: CupertinoIcons.person_crop_circle_fill,
                          iconColor: AppTheme.info,
                          title: c.name,
                          subtitle: [c.location, c.phone].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          onTap: () => showCustomerEditor(context, ref, existing: c),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
