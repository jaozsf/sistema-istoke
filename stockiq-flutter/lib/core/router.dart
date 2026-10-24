import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'utils/responsive.dart';
import '../shared/widgets/app_widgets.dart';
import '../shared/widgets/update_notice.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/products/products_screen.dart';
import '../features/products/product_detail_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/stock/stock_screen.dart';
import '../features/stock/movement_screen.dart';
import '../features/qr/qr_scanner_screen.dart';
import '../features/qr/qr_viewer_screen.dart';
import '../features/ai_assistant/ai_assistant_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/team/team_activity_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_form_screen.dart';
import '../features/admin/admin_hub_screen.dart';
import '../features/admin/box_standards_screen.dart';
import '../features/admin/distributors_screen.dart';
import '../features/admin/customers_screen.dart';
import '../features/errors/not_found_screen.dart';
import '../shared/models/user_model.dart';
import 'providers/auth_provider.dart';

// Rotas que só admin/manager pode ver — outros setores são jogados pra
// tela inicial do próprio setor.
const _managerOnlyRoutes = ['/dashboard', '/ai', '/team-activity'];

/// Tela inicial de cada setor.
String homeFor(UserModel? u) {
  if (u == null) return '/login';
  if (u.isManager) return '/dashboard';
  if (u.isSeller || u.isProduction || u.isShipping) return '/orders';
  return '/products';
}

// Navegar a partir de fora da árvore de widgets (ex: tap numa notificação
// push, sem BuildContext próprio) -- ver NotificationService.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.isLoggedIn ?? false;
      final isAuth = state.matchedLocation.startsWith('/login');

      if (!isLoggedIn && !isAuth) return '/login';
      final user = ref.read(currentUserProvider);
      if (isLoggedIn && isAuth) return homeFor(user);

      if (isLoggedIn) {
        final loc = state.matchedLocation;
        final isManagerOnlyRoute = _managerOnlyRoutes.any((r) => loc.startsWith(r));
        if (isManagerOnlyRoute && !(user?.isManager ?? false)) return homeFor(user);
        if (loc.startsWith('/customers') && !(user?.canSell ?? false)) return homeFor(user);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // Shell com bottom navigation
      ShellRoute(
        builder: (context, state, child) => UpdateGate(child: MainShell(child: child)),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsScreen(),
            routes: [
              GoRoute(path: 'new',     builder: (_, __) => const ProductFormScreen()),
              GoRoute(path: ':id',     builder: (_, s) => ProductDetailScreen(id: s.pathParameters['id']!)),
              GoRoute(path: ':id/edit',builder: (_, s) => ProductFormScreen(productId: s.pathParameters['id'])),
            ],
          ),
          GoRoute(
            path: '/stock',
            builder: (_, __) => const StockScreen(),
            routes: [
              GoRoute(path: 'movement', builder: (_, s) {
                final extra = s.extra as Map<String, dynamic>?;
                return MovementScreen(
                  productId:  extra?['productId'],
                  branchId:   extra?['branchId'],
                  initialType: extra?['type'] ?? 'entrada',
                );
              }),
            ],
          ),
          GoRoute(
            path: '/qr',
            builder: (_, __) => const QRScannerScreen(),
            routes: [
              GoRoute(path: 'view/:productId', builder: (_, s) => QRViewerScreen(productId: s.pathParameters['productId']!)),
            ],
          ),
          GoRoute(path: '/ai',             builder: (_, __) => const AiAssistantScreen()),
          GoRoute(path: '/team-activity',  builder: (_, __) => const TeamActivityScreen()),
          GoRoute(path: '/notifications',  builder: (_, __) => const NotificationsScreen()),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const OrderFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => OrderDetailScreen(id: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(
            path: '/admin',
            builder: (_, __) => const AdminHubScreen(),
            routes: [
              GoRoute(path: 'boxes',        builder: (_, __) => const BoxStandardsScreen()),
              GoRoute(path: 'distributors', builder: (_, __) => const DistributorsScreen()),
              GoRoute(path: 'customers',    builder: (_, __) => const CustomersScreen()),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
});

// ── Shell com tab bar ─────────────────────────────────────────────────────────

/// Um item de navegação -- alimenta tanto o tab bar (mobile) quanto
/// NavigationRailDestination (tablet/desktop) sem duplicar a lista.
typedef _NavItem = (IconData icon, IconData activeIcon, String label);

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(currentUserProvider);
    final isManager = user?.isManager ?? false;

    const _NavItem dashboardItem = (CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, 'Início');
    const _NavItem ordersItem    = (CupertinoIcons.doc_text, CupertinoIcons.doc_text_fill, 'Pedidos');
    const _NavItem customersItem = (CupertinoIcons.person_2, CupertinoIcons.person_2_fill, 'Clientes');
    const _NavItem productsItem  = (CupertinoIcons.cube_box, CupertinoIcons.cube_box_fill, 'Produtos');
    const _NavItem stockItem     = (CupertinoIcons.archivebox, CupertinoIcons.archivebox_fill, 'Estoque');
    const _NavItem qrItem        = (CupertinoIcons.qrcode_viewfinder, CupertinoIcons.qrcode_viewfinder, 'QR Code');
    final _NavItem moreItem      = (CupertinoIcons.gear_alt, CupertinoIcons.gear_alt_fill, isManager ? 'Gestão' : 'Conta');

    // Cada setor vê só as abas do próprio trabalho (bloqueio de verdade fica
    // no backend + redirect acima).
    final List<(String, _NavItem)> tabs = switch (user) {
      final u? when u.isManager    => [('/dashboard', dashboardItem), ('/orders', ordersItem), ('/products', productsItem), ('/stock', stockItem), ('/admin', moreItem)],
      final u? when u.isSeller     => [('/orders', ordersItem), ('/customers', customersItem), ('/products', productsItem), ('/admin', moreItem)],
      final u? when u.isProduction => [('/orders', ordersItem), ('/products', productsItem), ('/stock', stockItem), ('/admin', moreItem)],
      final u? when u.isShipping   => [('/orders', ordersItem), ('/stock', stockItem), ('/qr', qrItem), ('/admin', moreItem)],
      _                            => [('/products', productsItem), ('/stock', stockItem), ('/qr', qrItem), ('/admin', moreItem)],
    };
    final routes = [for (final t in tabs) t.$1];
    final navItems = [for (final t in tabs) t.$2];

    var currentIndex = routes.indexWhere((r) => location.startsWith(r));
    if (currentIndex < 0) currentIndex = 0;

    // Chave pela raiz da aba (não pela location inteira) -- troca de aba
    // dispara a transição, mas navegar dentro da mesma aba (ex: abrir um
    // produto) não, porque isso já anima via push normal do Navigator.
    final tabRoot = routes[currentIndex];

    void go(int i) {
      if (i != currentIndex) HapticFeedback.selectionClick();
      context.go(routes[i]);
    }

    final breakpoint = context.breakpoint;
    if (breakpoint == Breakpoint.mobile) {
      return Scaffold(
        // Conteúdo passa por baixo do tab bar translúcido (como no iOS)
        extendBody: true,
        body: _AnimatedTabBody(tabKey: tabRoot, child: child),
        bottomNavigationBar: _PillNavBar(items: navItems, currentIndex: currentIndex, onTap: go),
      );
    }

    final extended = breakpoint == Breakpoint.desktop;
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 210,
            selectedIndex: currentIndex,
            onDestinationSelected: go,
            backgroundColor: theme.scaffoldBackgroundColor,
            indicatorColor: theme.colorScheme.primaryContainer,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: extended
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 8),
                        AppLogo(size: 32),
                        SizedBox(width: 10),
                        BrandWordmark(size: 22),
                      ],
                    )
                  : const AppLogo(size: 32),
            ),
            destinations: [
              for (final item in navItems)
                NavigationRailDestination(
                  icon: Icon(item.$1),
                  selectedIcon: _PopIcon(icon: item.$2),
                  label: Text(item.$3),
                ),
            ],
          ),
          VerticalDivider(width: .5, thickness: .5, color: theme.colorScheme.outline),
          Expanded(child: _AnimatedTabBody(tabKey: tabRoot, child: child)),
        ],
      ),
    );
  }
}

// ── Animação de troca de aba ──────────────────────────────────────────────────

/// Fade + leve slide vertical ao trocar de aba do tab bar / rail.
/// Chaveado pela raiz da rota (não pela location completa) pra não disparar
/// de novo quando o usuário só navega dentro da mesma aba.
class _AnimatedTabBody extends StatelessWidget {
  final String tabKey;
  final Widget child;
  const _AnimatedTabBody({required this.tabKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(tabKey), child: child),
    );
  }
}

/// Ícone ativo "estoura" (pop-in) toda vez que vira o selecionado -- só um
/// TweenAnimationBuilder de escala, dispara sozinho quando o widget monta.
class _PopIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;
  const _PopIcon({required this.icon, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// Tab bar flutuante de vidro (blur + translúcido, estilo iOS) com pill
/// em gradiente Lagoon deslizando atrás do item selecionado.
class _PillNavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _PillNavBar({required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: dark ? .72 : .8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .7), width: .5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = constraints.maxWidth / items.length;
                return SizedBox(
                  height: 54,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutBack,
                        left: slotWidth * currentIndex,
                        top: 0,
                        bottom: 0,
                        width: slotWidth,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppTheme.brandGradient,
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: _PillNavItem(
                                item: items[i],
                                selected: i == currentIndex,
                                onTap: () => onTap(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _PillNavItem({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        label: item.$3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            selected ? _PopIcon(icon: item.$2, color: fg, size: 22) : Icon(item.$1, color: fg, size: 22),
            const SizedBox(height: 2),
            Text(
              item.$3,
              style: TextStyle(color: fg, fontSize: 10.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
