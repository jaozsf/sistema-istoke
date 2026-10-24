import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/logistics_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../shared/models/logistics_models.dart';
import '../../shared/models/user_model.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/ios_widgets.dart';
import 'icon_picker_sheet.dart';

/// Central do admin (dono): visão da esteira de pedidos + todos os
/// cadastros que alimentam o fluxo, no formato "Ajustes" do iPhone.
class AdminHubScreen extends ConsumerWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(orderSummaryProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isManager = user?.isManager ?? false;
    final canSell = user?.canSell ?? false;

    return IosPage(
      title: isManager ? 'Gestão' : 'Conta',
      onRefresh: () async => invalidateOrders(ref),
      slivers: [
        SliverToBoxAdapter(child: _ProfileCard(name: user?.fullName ?? '', role: user?.roleLabel ?? '', email: user?.email ?? '')),
        if (isManager) SliverToBoxAdapter(
          child: summary.maybeWhen(
            data: (s) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GridView.count(
                crossAxisCount: context.isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  StatTile(label: 'Em andamento', value: '${s.openTotal}', icon: CupertinoIcons.arrow_2_circlepath, color: AppTheme.lagoon, onTap: () => context.go('/orders')),
                  StatTile(label: 'Na produção', value: '${s.of(OrderStage.emProducao)}', icon: OrderStage.emProducao.icon, color: OrderStage.emProducao.color, onTap: () => context.go('/orders')),
                  StatTile(label: 'Na expedição', value: '${s.of(OrderStage.emSeparacao) + s.of(OrderStage.conferido)}', icon: OrderStage.emSeparacao.icon, color: OrderStage.emSeparacao.color, onTap: () => context.go('/orders')),
                  StatTile(label: 'Despachados hoje', value: '${s.dispatchedToday}', icon: OrderStage.despachado.icon, color: OrderStage.despachado.color, onTap: () => context.go('/orders')),
                ],
              ),
            ),
            orElse: () => const SizedBox(height: 8),
          ),
        ),
        SliverToBoxAdapter(
          child: IosSection(
            header: 'Fluxo de pedidos',
            children: [
              IosTile(icon: CupertinoIcons.doc_text_fill, iconColor: AppTheme.lagoon, title: 'Pedidos', subtitle: 'Vendedor → produção → expedição → distribuidora', onTap: () => context.go('/orders')),
              if (canSell)
                IosTile(icon: CupertinoIcons.person_2_fill, iconColor: AppTheme.info, title: 'Clientes', onTap: () => context.push('/admin/customers')),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: IosSection(
            header: 'Cadastros',
            children: [
              IosTile(icon: CupertinoIcons.cube_box_fill, iconColor: AppTheme.deep, title: 'Padrões de caixa', subtitle: 'Unidades, medidas e peso por modelo de copo', onTap: () => context.push('/admin/boxes')),
              IosTile(icon: CupertinoIcons.car_detailed, iconColor: AppTheme.success, title: 'Distribuidoras', subtitle: 'Quem leva a carga até o cliente', onTap: () => context.push('/admin/distributors')),
              if (isManager)
                IosTile(icon: CupertinoIcons.person_3_fill, iconColor: const Color(0xFF8E6BD8), title: 'Equipe e setores', subtitle: 'Vendedor, produção, expedição, gerente', onTap: () => context.push('/team-activity')),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: IosSection(
            header: 'Ferramentas',
            children: [
              IosTile(
                icon: CupertinoIcons.sparkles,
                iconColor: const Color(0xFFE0569B),
                title: 'Assistente IA',
                subtitle: 'Tire dúvidas sobre o sistema e o seu trabalho',
                onTap: () => context.push('/ai'),
              ),
              IosTile(icon: CupertinoIcons.qrcode_viewfinder, iconColor: AppTheme.abyss, title: 'Leitor de QR Code', onTap: () => context.push('/qr')),
              IosTile(icon: CupertinoIcons.bell_fill, iconColor: AppTheme.danger, title: 'Notificações', onTap: () => context.push('/notifications')),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: IosSection(
            header: 'Aparência',
            children: [
              IosTile(
                leading: const AppLogo(size: 30),
                title: 'Ícone do app',
                subtitle: 'Desenhos ou emojis de estoque, na cor que quiser',
                onTap: () => showIconPicker(context),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: CupertinoSlidingSegmentedControl<ThemeMode>(
                  groupValue: themeMode,
                  thumbColor: Theme.of(context).colorScheme.surface,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  children: const {
                    ThemeMode.light: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Claro')),
                    ThemeMode.dark: Text('Escuro'),
                    ThemeMode.system: Text('Automático'),
                  },
                  onValueChanged: (m) {
                    if (m == null) return;
                    Haptics.tap();
                    ref.read(themeModeProvider.notifier).setMode(m);
                  },
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: IosSection(
            children: [
              IosTile(
                title: 'Sair da conta',
                destructive: true,
                chevron: false,
                onTap: () async {
                  final ok = await showIosConfirm(context,
                      title: 'Encerrar sessão?', confirmLabel: 'Sair', destructive: true);
                  if (!ok) return;
                  await ref.read(authStateProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name, role, email;
  const _ProfileCard({required this.name, required this.role, required this.email});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.brandGradient),
                child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleLarge),
                    Text(email, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimaryContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
