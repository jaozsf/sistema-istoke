import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';

class DistributorsScreen extends ConsumerWidget {
  const DistributorsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [Distributor? d]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DistributorEditor(existing: d),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final list = ref.watch(distributorsProvider(true));
    return IosPage(
      title: 'Distribuidoras',
      onRefresh: () async => ref.invalidate(distributorsProvider),
      actions: [
        if (isAdmin) IconButton(icon: const Icon(CupertinoIcons.add), onPressed: () => _edit(context, ref)),
      ],
      slivers: [
        list.when(
          loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator())),
          error: (e, _) => SliverToBoxAdapter(child: ErrorState(message: e.toString(), onRetry: () => ref.invalidate(distributorsProvider))),
          data: (items) {
            final active = items.where((d) => d.isActive).toList();
            final inactive = items.where((d) => !d.isActive).toList();
            if (items.isEmpty) {
              return SliverToBoxAdapter(
                child: EmptyState(
                  icon: CupertinoIcons.car_detailed,
                  title: 'Nenhuma distribuidora',
                  subtitle: 'Cadastre as transportadoras que o vendedor pode escolher com o cliente.',
                  actionLabel: isAdmin ? 'Cadastrar' : null,
                  onAction: isAdmin ? () => _edit(context, ref) : null,
                ),
              );
            }
            return SliverToBoxAdapter(
              child: Column(
                children: [
                  IosSection(
                    header: 'Ativas',
                    footer: 'Aparecem pro vendedor ao montar o pedido.',
                    children: [
                      for (final d in active)
                        IosTile(
                          icon: CupertinoIcons.car_detailed,
                          title: d.name,
                          subtitle: [d.contactName, d.phone, d.regions].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          onTap: isAdmin ? () => _edit(context, ref, d) : null,
                        ),
                    ],
                  ),
                  if (inactive.isNotEmpty)
                    IosSection(
                      header: 'Inativas',
                      children: [
                        for (final d in inactive)
                          IosTile(
                            icon: CupertinoIcons.car_detailed,
                            iconColor: Colors.grey,
                            title: d.name,
                            onTap: isAdmin ? () => _edit(context, ref, d) : null,
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DistributorEditor extends ConsumerStatefulWidget {
  final Distributor? existing;
  const _DistributorEditor({this.existing});

  @override
  ConsumerState<_DistributorEditor> createState() => _DistributorEditorState();
}

class _DistributorEditorState extends ConsumerState<_DistributorEditor> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _cnpj = TextEditingController(text: widget.existing?.cnpj);
  late final _contact = TextEditingController(text: widget.existing?.contactName);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _regions = TextEditingController(text: widget.existing?.regions);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late bool _active = widget.existing?.isActive ?? true;
  bool _saving = false;

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showIosToast(context, 'Informe o nome.', error: true);
    setState(() => _saving = true);
    try {
      await ref.read(logisticsApiProvider).saveDistributor(widget.existing?.id, {
        'name': _name.text.trim(),
        'cnpj': _v(_cnpj),
        'contact_name': _v(_contact),
        'phone': _v(_phone),
        'email': _v(_email),
        'regions': _v(_regions),
        'notes': _v(_notes),
        'is_active': _active,
      });
      ref.invalidate(distributorsProvider);
      if (mounted) {
        Navigator.pop(context);
        showIosToast(context, 'Distribuidora salva');
      }
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
            Text(widget.existing == null ? 'Nova distribuidora' : 'Editar distribuidora', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome *')),
            const SizedBox(height: 10),
            TextField(controller: _cnpj, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CNPJ')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contato'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone'))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
            const SizedBox(height: 10),
            TextField(controller: _regions, decoration: const InputDecoration(labelText: 'Regiões atendidas', hintText: 'Norte do PR, interior de SP...')),
            const SizedBox(height: 10),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _active,
              activeTrackColor: AppTheme.success,
              title: const Text('Ativa'),
              subtitle: const Text('Inativa some da escolha do vendedor'),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 12),
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
