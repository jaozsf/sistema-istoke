import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/services/stock_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/movement_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';

const _roles = ['operator', 'manager', 'admin'];
const _roleLabels = {'operator': 'Operador', 'manager': 'Gerente', 'admin': 'Admin'};

/// Painel do admin/manager: aba 1 mostra o que cada funcionário fez
/// (movimentação por movimentação); aba 2 cadastra pessoas e define cargo.
class TeamActivityScreen extends StatelessWidget {
  const TeamActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Equipe'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Atividade'),
            Tab(text: 'Pessoas'),
          ]),
        ),
        body: const TabBarView(
          children: [_ActivityTab(), _PeopleTab()],
        ),
      ),
    );
  }
}

// ── Aba: Atividade ──────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerStatefulWidget {
  const _ActivityTab();

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    final movements = ref.watch(teamActivityProvider);

    return users.when(
      data: (userList) {
        final userById = {for (final u in userList) u.id: u};

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedUserId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Funcionário',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                  ...userList.map((u) => DropdownMenuItem<String?>(
                        value: u.id,
                        child: Text('${u.fullName} (${_roleLabels[u.role] ?? u.role})', overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedUserId = v),
              ),
            ),
            Expanded(
              child: movements.when(
                data: (items) {
                  final filtered = _selectedUserId == null
                      ? items
                      : items.where((m) => m.userId == _selectedUserId).toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'Nenhuma movimentação encontrada',
                      subtitle: 'Ninguém registrou nada com esse filtro ainda.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(teamActivityProvider);
                      ref.invalidate(usersProvider);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ActivityTile(
                        movement: filtered[i],
                        user: userById[filtered[i].userId],
                      ),
                    ),
                  );
                },
                loading: () => ListView(
                  padding: const EdgeInsets.all(16),
                  children: List.generate(6, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: ShimmerCard(height: 70),
                  )),
                ),
                error: (e, _) => ErrorState(
                  message: 'Erro ao carregar movimentações',
                  onRetry: () => ref.invalidate(teamActivityProvider),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(
        message: 'Erro ao carregar funcionários',
        onRetry: () => ref.invalidate(usersProvider),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  final MovementModel movement;
  final UserModel? user;
  const _ActivityTile({required this.movement, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(movement.productId));
    final color = movement.isEntrada
        ? AppTheme.success
        : movement.isSaida
            ? AppTheme.danger
            : AppTheme.info;
    final icon = movement.isEntrada
        ? Icons.add_circle_outline
        : movement.isSaida
            ? Icons.remove_circle_outline
            : Icons.swap_horiz;
    final sign = movement.isEntrada ? '+' : movement.isSaida ? '-' : '↔';
    final when = DateTime.tryParse(movement.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user?.fullName ?? 'Usuário removido',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (when != null)
                  Text(
                    DateFormat('dd/MM HH:mm').format(when.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.when(
                      data: (p) => p.name,
                      loading: () => 'Carregando...',
                      error: (_, __) => movement.productId,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$sign${movement.quantity}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
            if (movement.hasArt || movement.hasBorder) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  if (movement.hasArt) const StatusBadge(label: 'Personalizado', type: StatusType.info),
                  if (movement.hasBorder) const StatusBadge(label: 'Com borda', type: StatusType.info),
                ],
              ),
            ],
            if (movement.notes != null && movement.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(movement.notes!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Aba: Pessoas ─────────────────────────────────────────────────────────────

class _PeopleTab extends ConsumerWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPersonDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar pessoa'),
      ),
      body: users.when(
        data: (userList) {
          if (userList.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'Ninguém cadastrado ainda',
              subtitle: 'Toca em "Adicionar pessoa" pra convidar alguém.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(usersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: userList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PersonTile(user: userList[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Erro ao carregar pessoas',
          onRetry: () => ref.invalidate(usersProvider),
        ),
      ),
    );
  }
}

class _PersonTile extends ConsumerWidget {
  final UserModel user;
  const _PersonTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: .12),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(user.fullName, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${user.email}${user.firebaseUid == null ? ' · convite pendente' : ''}',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: TextButton(
          onPressed: () => _showEditRoleDialog(context, ref, user),
          child: Text(_roleLabels[user.role] ?? user.role),
        ),
      ),
    );
  }
}

void _showAddPersonDialog(BuildContext context, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  String role = 'operator';
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Adicionar pessoa'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome completo *'),
                validator: (v) => (v == null || v.isEmpty) ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail *'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe o e-mail.';
                  if (!v.contains('@')) return 'E-mail inválido.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Cargo'),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabels[r]!)))
                    .toList(),
                onChanged: (v) => setState(() => role = v!),
              ),
              const SizedBox(height: 8),
              Text(
                'A pessoa entra no sistema fazendo login com esse mesmo e-mail (Google ou e-mail/senha). O cargo já fica pronto esperando.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              try {
                await StockApiService().createUser(
                  email: emailCtrl.text.trim(),
                  fullName: nameCtrl.text.trim(),
                  role: role,
                );
                ref.invalidate(usersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Pessoa adicionada!'), backgroundColor: AppTheme.success),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
                );
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    ),
  );
}

void _showEditRoleDialog(BuildContext context, WidgetRef ref, UserModel user) {
  String role = user.role;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Cargo de ${user.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _roles.map((r) => RadioListTile<String>(
                value: r,
                groupValue: role,
                title: Text(_roleLabels[r]!),
                onChanged: (v) => setState(() => role = v!),
              )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await StockApiService().updateUserRole(user.id, role);
                ref.invalidate(usersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}
