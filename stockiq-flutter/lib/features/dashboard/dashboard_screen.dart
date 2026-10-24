import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/logistics_providers.dart';
import '../../shared/models/logistics_models.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/app_notifications.dart';
import '../../core/services/pdf_download.dart';
import '../../core/services/stock_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/animations.dart';
import '../../core/utils/responsive.dart';
import '../../shared/models/movement_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';

PopupMenuItem<String> _themeMenuItem(
  BuildContext context, String value, IconData icon, String label, bool selected,
) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: selected ? AppTheme.primary : null),
        const SizedBox(width: 10),
        Text(label, style: selected ? const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600) : null),
        if (selected) ...[
          const Spacer(),
          const Icon(Icons.check, size: 16, color: AppTheme.primary),
        ],
      ],
    ),
  );
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user      = ref.watch(currentUserProvider);
    final lowStock  = ref.watch(lowStockProvider);
    final movements = ref.watch(movementsProvider);
    final finance   = ref.watch(financeSummaryProvider(1));
    final themeMode = ref.watch(themeModeProvider);
    final orders    = ref.watch(orderSummaryProvider);

    // Avisa (notificação real do SO/navegador) quando o estoque baixo
    // muda de "sem alerta" pra "tem alerta" — dispara uma vez por troca
    // de estado, não a cada rebuild.
    ref.listen(lowStockProvider, (previous, next) {
      final items = next.valueOrNull;
      final hadNone = previous?.valueOrNull?.isEmpty ?? true;
      if (items != null && items.isNotEmpty && hadNone) {
        AppNotifications.notify(
          'Estoque baixo',
          '${items.length} produto(s) abaixo do mínimo.',
        );
      }
    });
    final currency  = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olá, ${user?.fullName.split(' ').first ?? 'Usuário'} 👋',
                style: const TextStyle(fontSize: 15)),
            Text(
              DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (user?.isManager ?? false)
            IconButton(
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Atividade da equipe',
              onPressed: () => context.push('/team-activity'),
            ),
          if (user?.isManager ?? false)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Baixar relatório executivo (PDF)',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final bytes = await StockApiService().getExecutiveReportPdf();
                  await downloadBytes(bytes, 'stockiq_relatorio_executivo.pdf');
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Erro ao baixar relatório: $e'), backgroundColor: AppTheme.danger),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Conta',
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const PopupMenuDivider(),
              _themeMenuItem(context, 'theme_light', Icons.light_mode_outlined, 'Claro', themeMode == ThemeMode.light),
              _themeMenuItem(context, 'theme_dark', Icons.dark_mode_outlined, 'Escuro', themeMode == ThemeMode.dark),
              _themeMenuItem(context, 'theme_system', Icons.brightness_auto_outlined, 'Sistema', themeMode == ThemeMode.system),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Sair', style: TextStyle(color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'theme_light':
                  ref.read(themeModeProvider.notifier).setMode(ThemeMode.light);
                  return;
                case 'theme_dark':
                  ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
                  return;
                case 'theme_system':
                  ref.read(themeModeProvider.notifier).setMode(ThemeMode.system);
                  return;
              }
              if (value != 'logout') return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Encerrar sessão?'),
                  content: const Text('Você vai precisar fazer login de novo pra acessar o sistema.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authStateProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lowStockProvider);
          ref.invalidate(movementsProvider);
          ref.invalidate(orderSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Métricas
                  GridView.count(
                    crossAxisCount: context.isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: context.isWide ? 1.9 : 1.6,
                    children: [
                      finance.when(
                        data: (f) => MetricCard(
                          label: 'Receita hoje',
                          value: currency.format(f.receita),
                          delta: f.receita > 0 ? 'Hoje' : 'Nenhuma venda ainda',
                          deltaPositive: true,
                        ).entrance(index: 0),
                        loading: () => const ShimmerCard(height: 80),
                        error: (_, __) => const MetricCard(label: 'Receita hoje', value: '--'),
                      ),
                      finance.when(
                        data: (f) => MetricCard(
                          label: 'Lucro líquido',
                          value: currency.format(f.lucro),
                          delta: f.lucro > 0 ? 'Hoje' : 'Nenhuma venda ainda',
                          deltaPositive: true,
                          valueColor: AppTheme.success,
                        ).entrance(index: 1),
                        loading: () => const ShimmerCard(height: 80),
                        error: (_, __) => const MetricCard(label: 'Lucro líquido', value: '--'),
                      ),
                      movements.when(
                        data: (items) => MetricCard(
                          label: 'Movimentações',
                          value: '${items.length}',
                          delta: 'Total',
                          deltaPositive: true,
                        ).entrance(index: 2),
                        loading: () => const ShimmerCard(height: 80),
                        error: (_, __) => const MetricCard(label: 'Movimentações', value: '--'),
                      ),
                      lowStock.when(
                        data: (items) => MetricCard(
                          label: 'Alertas de estoque',
                          value: '${items.length}',
                          delta: items.isEmpty ? 'Tudo OK' : 'Itens críticos',
                          deltaPositive: items.isEmpty,
                          valueColor: items.isNotEmpty ? AppTheme.warning : null,
                        ).entrance(index: 3),
                        loading: () => const ShimmerCard(height: 80),
                        error: (_, __) => const MetricCard(label: 'Alertas', value: '--'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Esteira de pedidos (vendedor -> produção -> expedição)
                  orders.maybeWhen(
                    data: (s) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(title: 'Esteira de pedidos', action: 'Abrir', onAction: () => context.go('/orders')),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final st in OrderStage.flow)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: Material(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => context.go('/orders'),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Column(
                                          children: [
                                            Icon(st.icon, size: 18, color: st.color),
                                            const SizedBox(height: 4),
                                            Text('${s.of(st)}', style: Theme.of(context).textTheme.titleLarge),
                                            Text(st.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.labelSmall),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    orElse: () => const SizedBox(),
                  ),

                  // Alertas de estoque baixo
                  lowStock.when(
                    data: (items) {
                      if (items.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Alertas de estoque',
                            action: 'Ver todos',
                            onAction: () => context.go('/stock'),
                          ),
                          const SizedBox(height: 8),
                          ...items.take(3).map((s) => _AlertTile(stock: s)),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                    loading: () => const ShimmerCard(height: 120),
                    error: (_, __) => const SizedBox(),
                  ),

                  // Movimentações recentes
                  SectionHeader(
                    title: 'Movimentações recentes',
                    action: 'Ver todas',
                    onAction: () => context.go('/stock'),
                  ),
                  const SizedBox(height: 8),
                  movements.when(
                    data: (items) => Column(
                      children: [
                        for (final (i, m) in items.take(5).indexed)
                          _MovementTile(movement: m).entrance(index: i),
                      ],
                    ),
                    loading: () => Column(
                      children: List.generate(4, (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ShimmerCard(height: 62),
                      )),
                    ),
                    error: (e, _) => ErrorState(
                      message: 'Erro ao carregar movimentações',
                      onRetry: () => ref.invalidate(movementsProvider),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final dynamic stock;
  const _AlertTile({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
        ),
        title: Text('Estoque abaixo do mínimo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${stock.quantity} unid disponíveis (mín ${stock.minQuantity})',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.go('/stock'),
      ),
    );
  }
}

class _MovementTile extends ConsumerWidget {
  final MovementModel movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEntrada = movement.isEntrada;
    final color = isEntrada ? AppTheme.success : AppTheme.danger;
    final icon  = isEntrada ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final sign  = isEntrada ? '+' : '-';
    final product = ref.watch(productDetailProvider(movement.productId));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          movement.type.toUpperCase(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          product.when(
            data: (p) => p.name,
            loading: () => 'Carregando...',
            error: (_, __) => movement.productId,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '$sign${movement.quantity}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}
